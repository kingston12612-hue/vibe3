const express=require('express');
const http=require('http');
const cors=require('cors');
const bcrypt=require('bcryptjs');
const jwt=require('jsonwebtoken');
const {Server}=require('socket.io');
const {Pool}=require('pg');

const app=express();
const server=http.createServer(app);
const io=new Server(server,{cors:{origin:'*'}});
// TLS обязателен для облачных БД (Neon и др.), локальным хостам не нужен
const _dbUrlRaw=process.env.DATABASE_URL||'';
const _dbUrl=_dbUrlRaw.trim().replace(/^["']+|["']+$/g,'');
const _dbLocal=/@(localhost|127\.0\.0\.1)/.test(_dbUrl);
let _dbHost='<НЕ ЗАДАН>';
try{ if(_dbUrl) _dbHost=new URL(_dbUrl).hostname; }catch(e){ _dbHost='<строка не разбирается!>'; }
console.log(`[db] DATABASE_URL: ${_dbUrl?'задан, host='+_dbHost:'НЕ ЗАДАН — сервер не сможет подключиться к БД'}`);
const pool=new Pool(_dbUrl&&!_dbLocal?{connectionString:_dbUrl,ssl:{rejectUnauthorized:false}}:{});
const SECRET=process.env.JWT_SECRET||'change-me';

// --- Контакты/верификация: утилиты ---
function normPhone(p){let s=String(p||'').replace(/[^\d+]/g,'');if(s.length===11&&s[0]==='8')s='+7'+s.slice(1);if(s&&!s.startsWith('+'))s='+'+s;return s;}
function validEmail(e){return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(e||''));}
function validPhone(p){return /^\+\d{7,15}$/.test(String(p||''));}
// кто сейчас подключён по сокету (для «в сети» в профилях)
const __online=new Set();
// === v1.3.1: доставка кодов — реальные шлюзы ===
// EMAIL (достаточно одного): RESEND_API_KEY (resend.com — 100 писем/день бесплатно),
//   BREVO_API_KEY (brevo.com — 300/день), SENDGRID_API_KEY (sendgrid.com — 100/день)
//   или SMTP_HOST+SMTP_USER+SMTP_PASS (например Gmail с паролем приложения, порт 465/587).
//   MAIL_FROM — адрес отправителя; для Resend без своего домена по умолчанию onboarding@resend.dev.
// SMS (достаточно одного): SMSRU_API_ID (sms.ru — на СВОЙ номер бесплатно, на другие ~1-2 руб.),
//   TWILIO_SID+TWILIO_TOKEN+TWILIO_FROM (twilio.com — trial даёт стартовый кредит)
//   или SMS_API_URL+SMS_API_KEY (произвольный шлюз: POST {to,text}).
// Ничего не задано — код показывается в приложении (delivery:'none', devCode): флоу работает сразу.
const _mailFrom=()=>String(process.env.MAIL_FROM||'onboarding@resend.dev').trim();
async function sendEmailCode(to,text){
 try{
  const subject='vibe<3 — код подтверждения';
  if(process.env.RESEND_API_KEY){
    const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+process.env.RESEND_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({from:_mailFrom(),to:[to],subject,text})});
    if(r.ok)return 'resend'; console.error('resend fail',r.status,await r.text().catch(()=>''));
  }
  if(process.env.BREVO_API_KEY){
    const r=await fetch('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':process.env.BREVO_API_KEY,'Content-Type':'application/json',accept:'application/json'},body:JSON.stringify({sender:{email:_mailFrom()},to:[{email:to}],subject,textContent:text})});
    if(r.ok)return 'brevo'; console.error('brevo fail',r.status,await r.text().catch(()=>''));
  }
  if(process.env.SENDGRID_API_KEY){
    const r=await fetch('https://api.sendgrid.com/v3/mail/send',{method:'POST',headers:{Authorization:'Bearer '+process.env.SENDGRID_API_KEY,'Content-Type':'application/json'},body:JSON.stringify({personalizations:[{to:[{email:to}]}],from:{email:_mailFrom()},subject,content:[{type:'text/plain',value:text}]})});
    if(r.ok)return 'sendgrid'; console.error('sendgrid fail',r.status,await r.text().catch(()=>''));
  }
  if(process.env.SMTP_HOST&&process.env.SMTP_USER&&process.env.SMTP_PASS){
    const nm=require('nodemailer');
    const tr=nm.createTransport({host:process.env.SMTP_HOST,port:Number(process.env.SMTP_PORT||587),secure:String(process.env.SMTP_PORT||'')==='465',auth:{user:process.env.SMTP_USER,pass:process.env.SMTP_PASS}});
    await tr.sendMail({from:process.env.SMTP_FROM||process.env.SMTP_USER,to,subject,text});
    return 'smtp';
  }
 }catch(e){console.error('sendEmailCode failed',e);}
 return 'none';
}
async function sendSmsCode(to,text){
 try{
  if(process.env.SMSRU_API_ID){
    const p=new URLSearchParams({api_id:process.env.SMSRU_API_ID,to:to.replace(/^\+/,''),msg:text,json:1});
    const r=await fetch('https://sms.ru/sms/send?'+p.toString());
    const j=r.ok?await r.json().catch(()=>null):null;
    if(j&&j.status==='OK')return 'smsru'; console.error('smsru fail',r.status,j&&j.status_text);
  }
  if(process.env.TWILIO_SID&&process.env.TWILIO_TOKEN&&process.env.TWILIO_FROM){
    const auth=Buffer.from(process.env.TWILIO_SID+':'+process.env.TWILIO_TOKEN).toString('base64');
    const r=await fetch('https://api.twilio.com/2010-04-01/Accounts/'+process.env.TWILIO_SID+'/Messages.json',{method:'POST',headers:{Authorization:'Basic '+auth,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({To:to,From:process.env.TWILIO_FROM,Body:text})});
    if(r.ok)return 'twilio'; console.error('twilio fail',r.status,await r.text().catch(()=>''));
  }
  if(process.env.SMS_API_URL&&process.env.SMS_API_KEY){
    const r=await fetch(process.env.SMS_API_URL,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+process.env.SMS_API_KEY},body:JSON.stringify({to,text})});
    if(r.ok)return 'custom'; console.error('custom sms fail',r.status);
  }
 }catch(e){console.error('sendSmsCode failed',e);}
 return 'none';
}
async function sendCode(purpose,target,code){
 const emailText='Ваш код подтверждения vibe<3: '+code+'\nКод действует 15 минут. Никому его не сообщайте.\nЕсли вы не запрашивали код — просто проигнорируйте это письмо.';
 if(purpose==='email')return sendEmailCode(target.slice(6),emailText);
 if(purpose==='phone')return sendSmsCode(target.slice(6),'vibe<3: код подтверждения '+code+' (действует 15 минут)');
 return 'none';
}
// Ограничение частоты: не чаще 1 раза в 30 секунд, максимум 5 кодов в час на один адрес/номер
const _rlMap=new Map();
function rateOk(k){
 const now=Date.now();const a=(_rlMap.get(k)||[]).filter(t=>now-t<3600000);
 if(a.length>=5||(a.length&&now-a[a.length-1]<30000)){_rlMap.set(k,a);return false;}
 a.push(now);_rlMap.set(k,a);return true;
}
function normTarget(purpose,raw){
 if(purpose==='email'){const e=String(raw||'').trim().toLowerCase();return validEmail(e)?('email:'+e):null;}
 if(purpose==='phone'){const p=normPhone(raw);return validPhone(p)?('phone:'+p):null;}
 return null;
}

app.use(cors());
app.use(express.json({limit:'10mb'}));
app.get('/health',async(_,res)=>{try{await pool.query('SELECT 1');res.json({ok:true,service:'vibe<3',database:true});}catch(e){console.error('health',e);res.status(503).json({ok:false,database:false});}});

// v1.3.1: какие каналы доставки кодов подключены (только флаги, без секретов)
app.get('/delivery/status',(_,res)=>res.json({
 email:{resend:!!process.env.RESEND_API_KEY,brevo:!!process.env.BREVO_API_KEY,sendgrid:!!process.env.SENDGRID_API_KEY,smtp:!!(process.env.SMTP_HOST&&process.env.SMTP_USER&&process.env.SMTP_PASS)},
 sms:{smsru:!!process.env.SMSRU_API_ID,twilio:!!(process.env.TWILIO_SID&&process.env.TWILIO_TOKEN&&process.env.TWILIO_FROM),custom:!!(process.env.SMS_API_URL&&process.env.SMS_API_KEY)},
 hint:'EMAIL: RESEND_API_KEY или BREVO_API_KEY или SENDGRID_API_KEY или SMTP_HOST/SMTP_USER/SMTP_PASS (+MAIL_FROM). SMS: SMSRU_API_ID (на свой номер бесплатно) или TWILIO_SID/TWILIO_TOKEN/TWILIO_FROM. Ключи добавляются в Render -> Environment -> Environment Variables.'
}));

// --- /debug/log: журнал ошибок с телефонов (серый экран -> читаемый текст) ---
const debugLogs=[];
app.post('/debug/log',(req,res)=>{try{
  const m=String(req.body?.msg||'').slice(0,4000);
  const line=new Date().toISOString()+' | '+(req.body?.v?('v'+req.body.v+' | '):'')+m.replace(/\s+/g,' ').trim();
  debugLogs.push(line); if(debugLogs.length>300)debugLogs.splice(0,debugLogs.length-300);
  console.log('[debug-log]',line);
}catch(_){} res.json({ok:true});});
app.get('/debug/log',(_,res)=>res.json({count:debugLogs.length,logs:debugLogs.slice(-120)}));

function token(user){return jwt.sign({id:user.id,email:user.email,name:user.display_name},SECRET,{expiresIn:'30d'});}
function auth(req,res,next){try{req.user=jwt.verify((req.headers.authorization||'').replace(/^Bearer /,''),SECRET);next();}catch{res.status(401).json({error:'unauthorized'});}}

app.post('/auth/request-code',async(req,res)=>{try{
 const purpose=String(req.body?.purpose||'');
 const target=normTarget(purpose,req.body?.target);
 if(!target)return res.status(400).json({error:purpose==='phone'?'invalid_phone':'invalid_email'});
 if(!rateOk(target))return res.status(429).json({error:'too_many_requests'});
 const code=String(Math.floor(100000+Math.random()*900000));
 await pool.query(`INSERT INTO verify_codes(target,code,purpose,verified,created_at) VALUES($1,$2,$3,FALSE,now())
   ON CONFLICT(target) DO UPDATE SET code=$2,purpose=$3,verified=FALSE,created_at=now()`,[target,code,purpose]);
 const delivery=await sendCode(purpose,target,code);
 const out={ok:true,delivery};
 if(delivery==='none'){out.devCode=code;console.log('[verify-code]',target,code);}
 res.json(out);
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.post('/auth/verify-code',async(req,res)=>{try{
 const purpose=String(req.body?.purpose||'');
 const target=normTarget(purpose,req.body?.target);
 if(!target)return res.status(400).json({error:purpose==='phone'?'invalid_phone':'invalid_email'});
 const code=String(req.body?.code||'').trim();
 const r=await pool.query('SELECT code,verified,created_at FROM verify_codes WHERE target=$1',[target]);
 if(!r.rowCount)return res.status(400).json({error:'code_invalid'});
 const row=r.rows[0];
 if(row.verified)return res.json({ok:true,already:true});
 if(new Date(row.created_at).getTime()<Date.now()-15*60*1000)return res.status(400).json({error:'code_expired'});
 if(row.code!==code)return res.status(400).json({error:'code_invalid'});
 await pool.query('UPDATE verify_codes SET verified=TRUE WHERE target=$1',[target]);
 // если код подтверждает цель уже вошедшего юзера — сразу ставим флаг в профиле
 try{
  const me=jwt.verify((req.headers.authorization||'').replace(/^Bearer /,''),SECRET);
  const u=await pool.query('SELECT email,phone FROM users WHERE id=$1',[me.id]);
  if(u.rowCount){
   if(purpose==='email'&&('email:'+String(u.rows[0].email||'').toLowerCase())===target)await pool.query('UPDATE users SET email_verified=TRUE WHERE id=$1',[me.id]);
   if(purpose==='phone'&&u.rows[0].phone&&('phone:'+String(u.rows[0].phone))===target)await pool.query('UPDATE users SET phone_verified=TRUE WHERE id=$1',[me.id]);
  }
 }catch(_){}
 res.json({ok:true});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.post('/auth/register',async(req,res)=>{try{
 const email=String(req.body?.email||'').trim().toLowerCase(),name=String(req.body?.name||'').trim(),password=String(req.body?.password||''),rawUsername=String(req.body?.username||'').trim().toLowerCase();
 const username=rawUsername.replace(/^@/,'');
 const phone=normPhone(req.body?.phone||'');
 if(!validPhone(phone))return res.status(400).json({error:'invalid_phone'});
 if(!validEmail(email)||!name||name.length<2||password.length<6||!username||!/^[a-z0-9_]{3,30}$/.test(username))return res.status(400).json({error:'invalid_username'});
 // подтверждения обязательны: телефон и почта должны быть проверены кодом за последние 30 минут
 const pc=await pool.query("SELECT 1 FROM verify_codes WHERE target=$1 AND verified=TRUE AND created_at>now()-interval '30 minutes'",['phone:'+phone]);
 if(!pc.rowCount)return res.status(403).json({error:'phone_not_verified'});
 const ec=await pool.query("SELECT 1 FROM verify_codes WHERE target=$1 AND verified=TRUE AND created_at>now()-interval '30 minutes'",['email:'+email]);
 if(!ec.rowCount)return res.status(403).json({error:'email_not_verified'});
 const exists=await pool.query('SELECT id FROM users WHERE email=$1',[email]);if(exists.rowCount)return res.status(409).json({error:'email_exists'});
 const hash=await bcrypt.hash(password,12);
 try{
   const r=await pool.query('INSERT INTO users(email,username,display_name,password_hash,phone,email_verified,phone_verified) VALUES($1,$2,$3,$4,$5,TRUE,TRUE) RETURNING id,email,username,display_name',[email,username,name,hash,phone]);
   var u=r.rows[0];
 }catch(e){
   if(e.code==='23505'&&String(e.constraint||e.detail||'').toLowerCase().includes('email')) return res.status(409).json({error:'email_exists'});
   if(e.code==='23505'&&String(e.constraint||e.detail||'').toLowerCase().includes('username')) return res.status(409).json({error:'username_taken'});
   if(e.code==='23505') return res.status(409).json({error:'phone_taken'});
   throw e;
 }
 res.json({token:token(u),user:{id:u.id,email:u.email,username:u.username,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.post('/auth/login',async(req,res)=>{try{
 let login=String(req.body?.email||'').trim(),password=String(req.body?.password||'');
 const asPhone=normPhone(login);
 login=login.toLowerCase();
 const r=await pool.query('SELECT id,email,username,display_name,password_hash FROM users WHERE email=$1 OR username=$1 OR phone=$2',[login,asPhone]);
 if(!r.rowCount||!(await bcrypt.compare(password,r.rows[0].password_hash)))return res.status(401).json({error:'invalid_credentials'});
 const u=r.rows[0];res.json({token:token(u),user:{id:u.id,email:u.email,username:u.username,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

const _ME_COLS='id,email,username,display_name,avatar_url,phone,COALESCE(bio,\'\') AS bio,COALESCE(email_verified,FALSE) AS email_verified,COALESCE(phone_verified,FALSE) AS phone_verified,COALESCE(show_online,true) AS show_online,COALESCE(show_typing,true) AS show_typing,COALESCE(show_reads,true) AS show_reads,COALESCE(block_screenshots,false) AS block_screenshots,COALESCE(allow_calls,true) AS allow_calls';
app.get('/me',auth,async(req,res)=>{const r=await pool.query(`SELECT ${_ME_COLS} FROM users WHERE id=$1`,[req.user.id]);if(!r.rowCount)return res.status(404).json({error:'user_not_found'});res.json(r.rows[0]);});
// Приватность: флаги хранятся на сервере, чтобы собеседник не видел твой статус даже через прямой запрос
function _privacy(body){
  const out={};
  for(const [k,col] of [['showOnline','show_online'],['showTyping','show_typing'],['showReads','show_reads'],['blockScreenshots','block_screenshots'],['allowCalls','allow_calls']]){
    if(typeof body?.[k]==='boolean')out[col]=body[k];
  }
  return out;
}
app.put('/me',auth,async(req,res)=>{try{
 const name=String(req.body?.name??'').trim();
 const rawUsername=String(req.body?.username??'').trim().toLowerCase().replace(/^@/,'');
 if(name.length<2)return res.status(400).json({error:'invalid_name'});
 if(!/^[a-z0-9_]{3,30}$/.test(rawUsername))return res.status(400).json({error:'invalid_username'});
 const current=await pool.query('SELECT id FROM users WHERE id=$1',[req.user.id]);
 if(!current.rowCount)return res.status(404).json({error:'user_not_found'});
 // Аватар: data:image/... base64, максимум ~500KB строки; '' = удалить фото
 let avatar=null;const rawAvatar=req.body?.avatar;
 if(rawAvatar!=null){
   const a=String(rawAvatar);
   if(a==='')avatar='';
   else if(/^data:image\/(png|jpeg|jpg|webp);base64,[A-Za-z0-9+/=]+$/.test(a)&&a.length<=520000)avatar=a.slice(0,520000);
   else return res.status(400).json({error:'invalid_avatar'});
 }
 const pr=_privacy(req.body);
 const sets=['display_name=$1','username=$2'];const vals=[name,rawUsername];let i=3;
 if(avatar!=null){sets.push(`avatar_url=$${i++}`);vals.push(avatar===''?null:avatar);}
 if(req.body?.bio!=null){sets.push(`bio=$${i++}`);vals.push(String(req.body.bio).trim().slice(0,160));}
 for(const [col,v] of Object.entries(pr)){sets.push(`${col}=$${i++}`);vals.push(v);}
 vals.push(req.user.id);
 const r=await pool.query(`UPDATE users SET ${sets.join(', ')} WHERE id=$${i} RETURNING ${_ME_COLS}`,vals);
 if(!r.rowCount)return res.status(404).json({error:'user_not_found'});
 res.json(r.rows[0]);
}catch(e){
 console.error('profile_update_failed',e);
 if(e.code==='23505' && (String(e.constraint||'').includes('username') || String(e.detail||'').toLowerCase().includes('username'))) return res.status(409).json({error:'username_taken'});
 if(e.code==='22P02') return res.status(400).json({error:'invalid_user_id'});
 res.status(500).json({error:'profile_update_failed'});
}});

// v1.3.1: добавить/поменять телефон (нужен подтверждённый код: request-code purpose=phone → verify-code → этот вызов)
app.put('/me/phone',auth,async(req,res)=>{try{
 const phone=normPhone(req.body?.phone||'');
 if(!validPhone(phone))return res.status(400).json({error:'invalid_phone'});
 const pc=await pool.query("SELECT 1 FROM verify_codes WHERE target=$1 AND verified=TRUE AND created_at>now()-interval '30 minutes'",['phone:'+phone]);
 if(!pc.rowCount)return res.status(403).json({error:'phone_not_verified'});
 const dup=await pool.query('SELECT id FROM users WHERE phone=$1 AND id<>$2',[phone,req.user.id]);
 if(dup.rowCount)return res.status(409).json({error:'phone_taken'});
 const r=await pool.query(`UPDATE users SET phone=$1,phone_verified=TRUE WHERE id=$2 RETURNING ${_ME_COLS}`,[phone,req.user.id]);
 if(!r.rowCount)return res.status(404).json({error:'user_not_found'});
 res.json(r.rows[0]);
}catch(e){console.error('phone_update_failed',e);res.status(500).json({error:'server_error'});}});

// v1.3.1: добавить/поменять почту (нужен подтверждённый код: request-code purpose=email → verify-code → этот вызов)
app.put('/me/email',auth,async(req,res)=>{try{
 const email=String(req.body?.email||'').trim().toLowerCase();
 if(!validEmail(email))return res.status(400).json({error:'invalid_email'});
 const ec=await pool.query("SELECT 1 FROM verify_codes WHERE target=$1 AND verified=TRUE AND created_at>now()-interval '30 minutes'",['email:'+email]);
 if(!ec.rowCount)return res.status(403).json({error:'email_not_verified'});
 const dup=await pool.query('SELECT id FROM users WHERE email=$1 AND id<>$2',[email,req.user.id]);
 if(dup.rowCount)return res.status(409).json({error:'email_taken'});
 const r=await pool.query(`UPDATE users SET email=$1,email_verified=TRUE WHERE id=$2 RETURNING ${_ME_COLS}`,[email,req.user.id]);
 if(!r.rowCount)return res.status(404).json({error:'user_not_found'});
 res.json(r.rows[0]);
}catch(e){console.error('email_update_failed',e);res.status(500).json({error:'server_error'});}});

app.get('/users',auth,async(req,res)=>{const q=String(req.query.q||'').trim();const like='%'+q+'%';const r=await pool.query('SELECT id,username,display_name,avatar_url FROM users WHERE id<>$1 AND (username ILIKE $2 OR display_name ILIKE $2) ORDER BY display_name LIMIT 30',[req.user.id,like]);res.json(r.rows);});

// Профиль другого человека: bio, статус в сети/был(а), телефон видят только мои контакты, email не выдаётся никогда
app.get('/users/:id',auth,async(req,res)=>{try{
 const r=await pool.query('SELECT id,username,display_name,avatar_url,COALESCE(bio,\'\') AS bio,phone,COALESCE(show_online,true) AS show_online,last_seen_at FROM users WHERE id=$1',[req.params.id]);
 if(!r.rowCount)return res.status(404).json({error:'user_not_found'});
 const u=r.rows[0];
 const c=await pool.query('SELECT 1 FROM contacts WHERE owner_id=$1 AND contact_id=$2',[req.user.id,u.id]);
 const out={id:u.id,username:u.username,display_name:u.display_name,avatar_url:u.avatar_url,bio:u.bio,isContact:c.rowCount>0};
 if(u.show_online){out.online=__online.has(u.id);out.lastSeen=u.last_seen_at;}
 if(c.rowCount&&u.phone)out.phone=u.phone;
 res.json(out);
}catch(e){console.error('user_lookup_failed',e);res.status(500).json({error:'server_error'});}});

// --- Контакты: сохранённые люди (отдельно от поиска по всем юзерам) ---
app.get('/contacts',auth,async(req,res)=>{try{
 const r=await pool.query(`SELECT u.id,u.username,u.display_name,u.avatar_url,COALESCE(u.bio,'') AS bio,COALESCE(u.show_online,true) AS show_online,u.phone,u.last_seen_at
 FROM contacts c JOIN users u ON u.id=c.contact_id WHERE c.owner_id=$1 ORDER BY u.display_name LIMIT 300`,[req.user.id]);
 res.json(r.rows.map(x=>({id:x.id,username:x.username,display_name:x.display_name,avatar_url:x.avatar_url,bio:x.bio,online:__online.has(x.id)&&x.show_online,lastSeen:x.show_online?x.last_seen_at:null,phone:x.phone})));
}catch(e){console.error('contacts_failed',e);res.status(500).json({error:'server_error'});}});
app.post('/contacts',auth,async(req,res)=>{try{
 const uid=String(req.body?.userId||'');
 if(!uid)return res.status(400).json({error:'user_required'});
 if(uid===req.user.id)return res.status(400).json({error:'cannot_add_self'});
 const ex=await pool.query('SELECT 1 FROM users WHERE id=$1',[uid]);if(!ex.rowCount)return res.status(404).json({error:'user_not_found'});
 await pool.query('INSERT INTO contacts(owner_id,contact_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[req.user.id,uid]);
 res.json({ok:true});
}catch(e){console.error('contact_add_failed',e);res.status(500).json({error:'server_error'});}});
app.delete('/contacts/:userId',auth,async(req,res)=>{try{
 await pool.query('DELETE FROM contacts WHERE owner_id=$1 AND contact_id=$2',[req.user.id,req.params.userId]);
 res.json({ok:true});
}catch(e){console.error('contact_del_failed',e);res.status(500).json({error:'server_error'});}});

app.post('/chats',auth,async(req,res)=>{const title=String(req.body?.title||'Chat').trim();const group=!!req.body?.isGroup;const r=await pool.query('INSERT INTO chats(title,is_group,created_by) VALUES($1,$2,$3) RETURNING *',[title,group,req.user.id]);await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2)',[r.rows[0].id,req.user.id]);res.json(r.rows[0]);});

app.post('/chats/direct',auth,async(req,res)=>{try{
 const other=String(req.body?.userId||'');if(!other)return res.status(400).json({error:'user_required'});
 if(other===req.user.id)return res.status(400).json({error:'cannot_chat_self'});
 const existing=await pool.query(`SELECT c.id,c.title,COALESCE((SELECT body FROM messages m WHERE m.chat_id=c.id ORDER BY m.created_at DESC LIMIT 1),'') preview
 FROM chats c
 JOIN chat_members a ON a.chat_id=c.id AND a.user_id=$1
 JOIN chat_members b ON b.chat_id=c.id AND b.user_id=$2
 WHERE c.is_group=false
   AND (SELECT COUNT(*) FROM chat_members cmx WHERE cmx.chat_id=c.id)=2
 ORDER BY c.created_at DESC LIMIT 1`,[req.user.id,other]);
 if(existing.rowCount)return res.json(existing.rows[0]);
 const u=await pool.query('SELECT display_name FROM users WHERE id=$1',[other]);if(!u.rowCount)return res.status(404).json({error:'user_not_found'});
 const c=await pool.query('INSERT INTO chats(title,is_group,created_by) VALUES($1,false,$2) RETURNING id,title',[u.rows[0].display_name,req.user.id]);
 await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2),($1,$3)',[c.rows[0].id,req.user.id,other]);
 res.json({...c.rows[0],preview:''});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.get('/chats',auth,async(req,res)=>{const r=await pool.query(`SELECT c.*,
 CASE WHEN c.is_group THEN c.title
      ELSE COALESCE((SELECT u.display_name FROM chat_members cm2 JOIN users u ON u.id=cm2.user_id WHERE cm2.chat_id=c.id AND cm2.user_id<>$1 LIMIT 1),c.title)
 END AS title,
 CASE WHEN c.is_group THEN NULL
      ELSE (SELECT u.avatar_url FROM chat_members cm3 JOIN users u ON u.id=cm3.user_id WHERE cm3.chat_id=c.id AND cm3.user_id<>$1 LIMIT 1)
 END AS peer_avatar,
 CASE WHEN c.is_group THEN NULL
      ELSE (SELECT cm4.user_id::text FROM chat_members cm4 WHERE cm4.chat_id=c.id AND cm4.user_id<>$1 LIMIT 1)
 END AS peer_id,
 COALESCE((SELECT body FROM messages m WHERE m.chat_id=c.id ORDER BY m.created_at DESC LIMIT 1),'') preview,
 COALESCE((SELECT MAX(created_at) FROM messages m2 WHERE m2.chat_id=c.id),c.created_at) AS last_at,
 (SELECT COUNT(*) FROM messages m3 WHERE m3.chat_id=c.id AND m3.sender_id<>$1 AND m3.created_at>COALESCE(cm.last_read_at,cm.joined_at)) AS unread
 FROM chats c
 JOIN chat_members cm ON cm.chat_id=c.id
 WHERE cm.user_id=$1 AND (c.is_group=true OR (SELECT COUNT(*) FROM chat_members cmx WHERE cmx.chat_id=c.id)=2)
 ORDER BY COALESCE((SELECT MAX(created_at) FROM messages m2 WHERE m2.chat_id=c.id),c.created_at) DESC`,[req.user.id]);res.json(r.rows);});
app.post('/chats/:id/read',auth,async(req,res)=>{try{
 await pool.query('UPDATE chat_members SET last_read_at=now() WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
 // Приватность: если читатель выключил отчёты о прочтении — собеседник не узнает
 try{const me=await pool.query('SELECT COALESCE(show_reads,true) AS sr FROM users WHERE id=$1',[req.user.id]);if(me.rows[0]?.sr!==false)io.to('chat:'+req.params.id).emit('read',{chatId:String(req.params.id),userId:req.user.id});}catch(_){io.to('chat:'+req.params.id).emit('read',{chatId:String(req.params.id),userId:req.user.id});}
 res.json({ok:true});
}catch(e){console.error('read_mark_failed',e);res.status(500).json({error:'read_mark_failed'});}});

// Удалить чат: снимает моё членство; если участников не осталось — чат стирается целиком
app.delete('/chats/:id',auth,async(req,res)=>{try{
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
 if(!member.rowCount)return res.status(403).json({error:'not_member'});
 await pool.query('DELETE FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
 const left=await pool.query('SELECT COUNT(*)::int n FROM chat_members WHERE chat_id=$1',[req.params.id]);
 io.to('chat:'+req.params.id).emit('chatDeleted',{chatId:String(req.params.id)});
 if(!left.rows[0].n)await pool.query('DELETE FROM chats WHERE id=$1',[req.params.id]);
 res.json({ok:true});
}catch(e){console.error('chat_delete_failed',e);res.status(500).json({error:'chat_delete_failed'});}});

// Удалить своё сообщение (только автор)
app.delete('/chats/:id/messages/:mid',auth,async(req,res)=>{try{
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
 if(!member.rowCount)return res.status(403).json({error:'not_member'});
 const r=await pool.query('DELETE FROM messages WHERE id=$1 AND sender_id=$2 RETURNING id',[req.params.mid,req.user.id]);
 if(!r.rowCount)return res.status(404).json({error:'not_found'});
 io.to('chat:'+req.params.id).emit('messageDeleted',{chatId:String(req.params.id),id:String(req.params.mid)});
 res.json({ok:true});
}catch(e){console.error('msg_delete_failed',e);res.status(500).json({error:'msg_delete_failed'});}});

// Список участников чата (для групп)
app.get('/chats/:id/members',auth,async(req,res)=>{try{
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
 if(!member.rowCount)return res.status(403).json({error:'not_member'});
 const r=await pool.query('SELECT u.id,u.username,u.display_name FROM chat_members cm JOIN users u ON u.id=cm.user_id WHERE cm.chat_id=$1 ORDER BY u.display_name LIMIT 100',[req.params.id]);
 res.json(r.rows);
}catch(e){console.error('members_failed',e);res.status(500).json({error:'members_failed'});}});

// --- История звонков ---
app.post('/calls',auth,async(req,res)=>{try{
 const cid=String(req.body?.chatId||'');if(!cid)return res.status(400).json({error:'chat_required'});
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[cid,req.user.id]);
 if(!member.rowCount)return res.status(403).json({error:'not_member'});
 const o=await pool.query('SELECT user_id FROM chat_members WHERE chat_id=$1 AND user_id<>$2 LIMIT 1',[cid,req.user.id]);
 if(!o.rowCount)return res.status(400).json({error:'no_peer'});
 const r=await pool.query('INSERT INTO calls(chat_id,caller_id,callee_id,video,status,duration) VALUES($1,$2,$3,$4,$5,$6) RETURNING *',[cid,req.user.id,o.rows[0].user_id,req.body?.video==true,String(req.body?.status||'ended'),Math.max(0,Number(req.body?.duration)||0)]);
 res.json(r.rows[0]);
}catch(e){console.error('call_log_failed',e);res.status(500).json({error:'call_log_failed'});}});
app.get('/calls',auth,async(req,res)=>{try{
 const r=await pool.query(`SELECT cl.*,c.is_group,
 CASE WHEN c.is_group THEN c.title ELSE COALESCE((SELECT u.display_name FROM users u WHERE u.id=CASE WHEN cl.caller_id=$1 THEN cl.callee_id ELSE cl.caller_id END),c.title) END AS title,
 (SELECT u.avatar_url FROM users u WHERE u.id=CASE WHEN cl.caller_id=$1 THEN cl.callee_id ELSE cl.caller_id END) AS peer_avatar,
 CASE WHEN cl.caller_id=$1 THEN 'out' ELSE 'in' END AS direction
 FROM calls cl JOIN chats c ON c.id=cl.chat_id
 WHERE cl.caller_id=$1 OR cl.callee_id=$1 ORDER BY cl.created_at DESC LIMIT 50`,[req.user.id]);
 res.json(r.rows);
}catch(e){console.error('calls_list_failed',e);res.status(500).json({error:'calls_list_failed'});}});
app.post('/chats/:id/members',auth,async(req,res)=>{
 try{
  const owner=await pool.query('SELECT 1 FROM chat_members cm JOIN chats c ON c.id=cm.chat_id WHERE cm.chat_id=$1 AND cm.user_id=$2 AND c.is_group=true',[req.params.id,req.user.id]);
  if(!owner.rowCount)return res.status(403).json({error:'group_only'});
  const userId=String(req.body?.userId||'');if(!userId)return res.status(400).json({error:'user_required'});
  await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[req.params.id,userId]);
  res.json({ok:true});
 }catch(e){console.error('add_member_failed',e);res.status(500).json({error:'member_add_failed'});}
});
app.get('/chats/:id/peer',auth,async(req,res)=>{
 try{
  const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);
  if(!member.rowCount)return res.status(403).json({error:'not_member'});
  const r=await pool.query(`SELECT u.id,u.username,u.display_name,u.avatar_url,COALESCE(u.show_online,true) AS show_online,COALESCE(u.show_typing,true) AS show_typing,COALESCE(u.show_reads,true) AS show_reads,COALESCE(u.block_screenshots,false) AS block_screenshots,COALESCE(u.allow_calls,true) AS allow_calls FROM chat_members cm JOIN users u ON u.id=cm.user_id WHERE cm.chat_id=$1 AND cm.user_id<>$2 LIMIT 1`,[req.params.id,req.user.id]);
  if(!r.rowCount)return res.status(404).json({error:'peer_not_found'});
  res.json(r.rows[0]);
 }catch(e){console.error('peer_lookup_failed',e);res.status(500).json({error:'peer_lookup_failed'});}
});
app.get('/chats/:id/messages',auth,async(req,res)=>{const r=await pool.query('SELECT m.*,u.display_name sender_name FROM messages m JOIN users u ON u.id=m.sender_id JOIN chat_members cm ON cm.chat_id=m.chat_id WHERE m.chat_id=$1 AND cm.user_id=$2 ORDER BY m.created_at ASC LIMIT 200',[req.params.id,req.user.id]);res.json(r.rows);});
app.post('/chats/:id/messages',auth,async(req,res)=>{try{
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);if(!member.rowCount)return res.status(403).json({error:'not_member'});
 const body=String(req.body?.body||'').trim();if(!body)return res.status(400).json({error:'empty_message'});
 const r=await pool.query('INSERT INTO messages(chat_id,sender_id,body,message_type,media_url) VALUES($1,$2,$3,$4,$5) RETURNING *',[req.params.id,req.user.id,body,req.body?.type||'text',req.body?.mediaUrl||null]);
 io.to('chat:'+req.params.id).emit('message',r.rows[0]);
 notifyMembers(req.params.id,req.user.id,req.user.name,body);
 res.json(r.rows[0]);
}catch(e){console.error(e);res.status(500).json({error:'message_failed'});}});

io.use((s,next)=>{try{s.user=jwt.verify(s.handshake.auth?.token||'',SECRET);__online.add(s.user.id);next();}catch{next(new Error('unauthorized'));}});
// Уведомления всем, кроме отправителя: личная комната каждого участника
async function notifyMembers(chatId,senderId,senderName,body){
 try{
  const others=await pool.query('SELECT user_id FROM chat_members WHERE chat_id=$1 AND user_id<>$2',[chatId,senderId]);
  for(const o of others.rows)io.to('user:'+o.user_id).emit('notify',{chatId:String(chatId),fromName:String(senderName||'').slice(0,60),body:String(body||'').slice(0,120)});
 }catch(e){console.error('notify_failed',e);}
}

io.on('connection',s=>{
 s.join('user:'+s.user.id); // личная комната: уведомления + звонки без привязки к чату
 s.on('presence',async v=>{try{
   const me=await pool.query('SELECT COALESCE(show_online,true) AS so FROM users WHERE id=$1',[s.user.id]);
   if(me.rows[0]?.so===false)return; // приватность: статус «в сети» скрыт — никто не узнаёт
   s.broadcast.emit('presence',{userId:s.user.id,online:!!v});
 }catch(e){s.broadcast.emit('presence',{userId:s.user.id,online:!!v});}});
 s.on('joinChat',id=>s.join('chat:'+id));
 s.on('typing',async m=>{try{
   if(!m||!m.chatId)return;
   const me=await pool.query('SELECT COALESCE(show_typing,true) AS st FROM users WHERE id=$1',[s.user.id]);
   if(me.rows[0]?.st===false)return; // приватность: «печатает…» скрыто на сервере
   io.to('chat:'+m.chatId).emit('typing',{chatId:String(m.chatId),userId:s.user.id,typing:!!m.typing});
 }catch(e){if(m&&m.chatId)io.to('chat:'+m.chatId).emit('typing',{chatId:String(m.chatId),userId:s.user.id,typing:!!m.typing});}});
 s.on('message',async m=>{try{const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[m.chatId,s.user.id]);if(!member.rowCount)return;const r=await pool.query('INSERT INTO messages(chat_id,sender_id,body,message_type,media_url) VALUES($1,$2,$3,$4,$5) RETURNING *',[m.chatId,s.user.id,String(m.body||''),m.type||'text',m.mediaUrl||null]);io.to('chat:'+m.chatId).emit('message',r.rows[0]);notifyMembers(m.chatId,s.user.id,s.user.name,m.body);}catch(e){s.emit('error',{error:'message_failed'});}});
 // --- Сигналинг WebRTC-звонков: релей только между участниками чата ---
 s.on('call',async m=>{try{
   if(!m||!m.chatId||!m.to||!m.offer)return;
   const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[m.chatId,s.user.id]);
   const toMember=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[m.chatId,m.to]);
   if(!member.rowCount||!toMember.rowCount)return;
   // Приватность: если у получателя звонки запрещены — вызов даже не доставляется,
   // а звонящему сразу приходит «отклонено» (звонок блокирует сервер, не приложение)
   const callee=await pool.query('SELECT COALESCE(allow_calls,true) AS ac FROM users WHERE id=$1',[m.to]);
   if(callee.rows[0]?.ac===false){io.to('user:'+s.user.id).emit('call:end',{chatId:String(m.chatId),from:s.user.id,reason:'declined'});return;}
   io.to('user:'+m.to).emit('call',{chatId:String(m.chatId),from:s.user.id,name:String(m.name||'').slice(0,60),video:!!m.video,offer:m.offer});
 }catch(e){s.emit('error',{error:'call_failed'});}});
 s.on('call:answer',m=>{if(m&&m.to&&m.answer)io.to('user:'+m.to).emit('call:answer',{chatId:String(m.chatId||''),from:s.user.id,answer:m.answer});});
 s.on('call:ice',m=>{if(m&&m.to&&m.candidate)io.to('user:'+m.to).emit('call:ice',{chatId:String(m.chatId||''),from:s.user.id,candidate:m.candidate});});
 s.on('call:end',m=>{if(m&&m.to)io.to('user:'+m.to).emit('call:end',{chatId:String(m.chatId||''),from:s.user.id,reason:String(m.reason||'ended')});});
 s.on('disconnect',()=>{__online.delete(s.user.id);try{pool.query('UPDATE users SET last_seen_at=now() WHERE id=$1',[s.user.id]).catch(()=>{});}catch(_){} s.broadcast.emit('presence',{userId:s.user.id,online:false});});
});

async function migrate(){
  const statements=[
    'CREATE EXTENSION IF NOT EXISTS pgcrypto',
    `CREATE TABLE IF NOT EXISTS users(
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT UNIQUE NOT NULL,
      username TEXT UNIQUE,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      avatar_url TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`,
    `CREATE TABLE IF NOT EXISTS chats(
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      title TEXT NOT NULL DEFAULT 'Chat',
      is_group BOOLEAN NOT NULL DEFAULT false,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`,
    `CREATE TABLE IF NOT EXISTS messages(
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body TEXT NOT NULL DEFAULT '',
      message_type TEXT NOT NULL DEFAULT 'text',
      media_url TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`,
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT',
    'ALTER TABLE chats ADD COLUMN IF NOT EXISTS created_by UUID',
    "ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text'",
    'ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_url TEXT',
    `CREATE TABLE IF NOT EXISTS chat_members(
      chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY(chat_id,user_id)
    )`,
    'ALTER TABLE chat_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ',
    'CREATE INDEX IF NOT EXISTS idx_messages_chat_created ON messages(chat_id,created_at)',
    'CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id)',
    `CREATE TABLE IF NOT EXISTS calls(
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
      caller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      callee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      video BOOLEAN NOT NULL DEFAULT false,
      status TEXT NOT NULL DEFAULT 'ended',
      duration INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`,
    'CREATE INDEX IF NOT EXISTS idx_calls_users ON calls(caller_id,callee_id,created_at DESC)',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS show_online BOOLEAN NOT NULL DEFAULT TRUE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS show_typing BOOLEAN NOT NULL DEFAULT TRUE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS show_reads BOOLEAN NOT NULL DEFAULT TRUE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS block_screenshots BOOLEAN NOT NULL DEFAULT FALSE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS allow_calls BOOLEAN NOT NULL DEFAULT TRUE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT FALSE',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ',
    'CREATE UNIQUE INDEX IF NOT EXISTS users_phone_key ON users(phone) WHERE phone IS NOT NULL',
    `CREATE TABLE IF NOT EXISTS contacts(
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      contact_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY(owner_id,contact_id)
    )`,
    'CREATE INDEX IF NOT EXISTS idx_contacts_owner ON contacts(owner_id)',
    `CREATE TABLE IF NOT EXISTS verify_codes(
      target TEXT PRIMARY KEY,
      code TEXT NOT NULL,
      purpose TEXT NOT NULL,
      verified BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`,
    // v1.3.1: старые личные чаты могли создаться с флагом группы — из-за этого «Участники» и запрет звонков; 2 участника = личный чат
    'UPDATE chats SET is_group=false WHERE is_group=true AND (SELECT COUNT(*) FROM chat_members cmx WHERE cmx.chat_id=chats.id)=2'
  ];
  for(const sql of statements){
    try{await pool.query(sql);}
    catch(e){console.error('migration failed:',sql.slice(0,100),e);throw e;}
  }
  console.log('database schema ready');
  console.log('AUTH_DB_MIGRATION_OK');
}
migrate().then(()=>server.listen(process.env.PORT||3000,()=>console.log('vibe<3 server ready'))).catch(e=>{console.error(e);process.exit(1);});

// deployment trigger: profile username update is live

// force Railway to deploy current main with the live profile update endpoint
