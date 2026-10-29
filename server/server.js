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

app.use(cors());
app.use(express.json({limit:'10mb'}));
app.get('/health',async(_,res)=>{try{await pool.query('SELECT 1');res.json({ok:true,service:'vibe<3',database:true});}catch(e){console.error('health',e);res.status(503).json({ok:false,database:false});}});

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

app.post('/auth/register',async(req,res)=>{try{
 const email=String(req.body?.email||'').trim().toLowerCase(),name=String(req.body?.name||'').trim(),password=String(req.body?.password||''),rawUsername=String(req.body?.username||'').trim().toLowerCase();
 const username=rawUsername.replace(/^@/,'');
 if(!email.includes('@')||!name||name.length<2||password.length<6||!username||!/^[a-z0-9_]{3,30}$/.test(username))return res.status(400).json({error:'invalid_username'});
 const exists=await pool.query('SELECT id FROM users WHERE email=$1',[email]);if(exists.rowCount)return res.status(409).json({error:'email_exists'});
 const hash=await bcrypt.hash(password,12);
 try{
   const r=await pool.query('INSERT INTO users(email,username,display_name,password_hash) VALUES($1,$2,$3,$4) RETURNING id,email,username,display_name',[email,username,name,hash]);
   var u=r.rows[0];
 }catch(e){
   if(e.code==='23505' && String(e.constraint||'').includes('email')) return res.status(409).json({error:'email_exists'});
   if(e.code==='23505' && String(e.constraint||'').includes('username')) return res.status(409).json({error:'username_taken'});
   throw e;
 }
 res.json({token:token(u),user:{id:u.id,email:u.email,username:u.username,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.post('/auth/login',async(req,res)=>{try{
 const login=String(req.body?.email||'').trim().toLowerCase(),password=String(req.body?.password||'');
 const r=await pool.query('SELECT id,email,username,display_name,password_hash FROM users WHERE email=$1 OR username=$1',[login]);
 if(!r.rowCount||!(await bcrypt.compare(password,r.rows[0].password_hash)))return res.status(401).json({error:'invalid_credentials'});
 const u=r.rows[0];res.json({token:token(u),user:{id:u.id,email:u.email,username:u.username,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

const _ME_COLS='id,email,username,display_name,avatar_url,COALESCE(show_online,true) AS show_online,COALESCE(show_typing,true) AS show_typing,COALESCE(show_reads,true) AS show_reads';
app.get('/me',auth,async(req,res)=>{const r=await pool.query(`SELECT ${_ME_COLS} FROM users WHERE id=$1`,[req.user.id]);if(!r.rowCount)return res.status(404).json({error:'user_not_found'});res.json(r.rows[0]);});
// Приватность: флаги хранятся на сервере, чтобы собеседник не видел твой статус даже через прямой запрос
function _privacy(body){
  const out={};
  for(const [k,col] of [['showOnline','show_online'],['showTyping','show_typing'],['showReads','show_reads']]){
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

app.get('/users',auth,async(req,res)=>{const q=String(req.query.q||'').trim();const like='%'+q+'%';const r=await pool.query('SELECT id,username,display_name,avatar_url FROM users WHERE id<>$1 AND (username ILIKE $2 OR display_name ILIKE $2) ORDER BY display_name LIMIT 30',[req.user.id,like]);res.json(r.rows);});

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
  const r=await pool.query(`SELECT u.id,u.username,u.display_name,u.avatar_url,COALESCE(u.show_online,true) AS show_online,COALESCE(u.show_typing,true) AS show_typing,COALESCE(u.show_reads,true) AS show_reads FROM chat_members cm JOIN users u ON u.id=cm.user_id WHERE cm.chat_id=$1 AND cm.user_id<>$2 LIMIT 1`,[req.params.id,req.user.id]);
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

io.use((s,next)=>{try{s.user=jwt.verify(s.handshake.auth?.token||'',SECRET);next();}catch{next(new Error('unauthorized'));}});
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
   io.to('user:'+m.to).emit('call',{chatId:String(m.chatId),from:s.user.id,name:String(m.name||'').slice(0,60),video:!!m.video,offer:m.offer});
 }catch(e){s.emit('error',{error:'call_failed'});}});
 s.on('call:answer',m=>{if(m&&m.to&&m.answer)io.to('user:'+m.to).emit('call:answer',{chatId:String(m.chatId||''),from:s.user.id,answer:m.answer});});
 s.on('call:ice',m=>{if(m&&m.to&&m.candidate)io.to('user:'+m.to).emit('call:ice',{chatId:String(m.chatId||''),from:s.user.id,candidate:m.candidate});});
 s.on('call:end',m=>{if(m&&m.to)io.to('user:'+m.to).emit('call:end',{chatId:String(m.chatId||''),from:s.user.id,reason:String(m.reason||'ended')});});
 s.on('disconnect',()=>s.broadcast.emit('presence',{userId:s.user.id,online:false}));
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
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS show_reads BOOLEAN NOT NULL DEFAULT TRUE'
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
