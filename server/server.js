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
const pool=new Pool();
const SECRET=process.env.JWT_SECRET||'change-me';

app.use(cors());
app.use(express.json({limit:'10mb'}));
app.get('/health',async(_,res)=>{try{await pool.query('SELECT 1');res.json({ok:true,service:'vibe<3',database:true});}catch(e){console.error('health',e);res.status(503).json({ok:false,database:false});}});

function token(user){return jwt.sign({id:user.id,email:user.email,name:user.display_name},SECRET,{expiresIn:'30d'});}
function auth(req,res,next){try{req.user=jwt.verify((req.headers.authorization||'').replace(/^Bearer /,''),SECRET);next();}catch{res.status(401).json({error:'unauthorized'});}}

app.post('/auth/register',async(req,res)=>{try{
 const email=String(req.body?.email||'').trim().toLowerCase(),name=String(req.body?.name||'').trim(),password=String(req.body?.password||'');
 if(!email.includes('@')||!name||name.length<2||password.length<6)return res.status(400).json({error:'invalid_input'});
 const exists=await pool.query('SELECT id FROM users WHERE email=$1',[email]);if(exists.rowCount)return res.status(409).json({error:'email_exists'});
 const hash=await bcrypt.hash(password,12);
 const username=email.split('@')[0].replace(/[^a-zA-Z0-9_]/g,'_').slice(0,30)||`user_${Date.now()}`;
 let u;
 try{const r=await pool.query('INSERT INTO users(email,username,display_name,password_hash) VALUES($1,$2,$3,$4) RETURNING id,email,display_name',[email,username,name,hash]);u=r.rows[0];}
 catch(e){if(e.code==='23505')return res.status(409).json({error:'email_exists'});throw e;}
 res.json({token:token(u),user:{id:u.id,email:u.email,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.post('/auth/login',async(req,res)=>{try{
 const email=String(req.body?.email||'').trim().toLowerCase(),password=String(req.body?.password||'');
 const r=await pool.query('SELECT id,email,display_name,password_hash FROM users WHERE email=$1',[email]);
 if(!r.rowCount||!(await bcrypt.compare(password,r.rows[0].password_hash)))return res.status(401).json({error:'invalid_credentials'});
 const u=r.rows[0];res.json({token:token(u),user:{id:u.id,email:u.email,name:u.display_name}});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.get('/me',auth,async(req,res)=>{const r=await pool.query('SELECT id,email,display_name,avatar_url FROM users WHERE id=$1',[req.user.id]);if(!r.rowCount)return res.status(404).json({error:'user_not_found'});res.json(r.rows[0]);});
app.get('/users',auth,async(req,res)=>{const q='%'+String(req.query.q||'').trim()+'%';const r=await pool.query('SELECT id,email,display_name,avatar_url FROM users WHERE id<>$1 AND (display_name ILIKE $2 OR email ILIKE $2) ORDER BY display_name LIMIT 30',[req.user.id,q]);res.json(r.rows);});

app.post('/chats',auth,async(req,res)=>{const title=String(req.body?.title||'Chat').trim();const group=!!req.body?.isGroup;const r=await pool.query('INSERT INTO chats(title,is_group,created_by) VALUES($1,$2,$3) RETURNING *',[title,group,req.user.id]);await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2)',[r.rows[0].id,req.user.id]);res.json(r.rows[0]);});

app.post('/chats/direct',auth,async(req,res)=>{try{
 const other=String(req.body?.userId||'');if(!other)return res.status(400).json({error:'user_required'});
 if(other===req.user.id)return res.status(400).json({error:'cannot_chat_self'});
 const existing=await pool.query(`SELECT c.id,c.title,COALESCE((SELECT body FROM messages m WHERE m.chat_id=c.id ORDER BY m.created_at DESC LIMIT 1),'') preview
 FROM chats c JOIN chat_members a ON a.chat_id=c.id AND a.user_id=$1 JOIN chat_members b ON b.chat_id=c.id AND b.user_id=$2
 WHERE c.is_group=false LIMIT 1`,[req.user.id,other]);
 if(existing.rowCount)return res.json(existing.rows[0]);
 const u=await pool.query('SELECT display_name FROM users WHERE id=$1',[other]);if(!u.rowCount)return res.status(404).json({error:'user_not_found'});
 const c=await pool.query('INSERT INTO chats(title,is_group,created_by) VALUES($1,false,$2) RETURNING id,title',[u.rows[0].display_name,req.user.id]);
 await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2),($1,$3)',[c.rows[0].id,req.user.id,other]);
 res.json({...c.rows[0],preview:''});
}catch(e){console.error(e);res.status(500).json({error:'server_error'});}});

app.get('/chats',auth,async(req,res)=>{const r=await pool.query(`SELECT c.*,COALESCE((SELECT body FROM messages m WHERE m.chat_id=c.id ORDER BY m.created_at DESC LIMIT 1),'') preview FROM chats c JOIN chat_members cm ON cm.chat_id=c.id WHERE cm.user_id=$1 ORDER BY COALESCE((SELECT MAX(created_at) FROM messages m2 WHERE m2.chat_id=c.id),c.created_at) DESC`,[req.user.id]);res.json(r.rows);});
app.post('/chats/:id/members',auth,async(req,res)=>{await pool.query('INSERT INTO chat_members(chat_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[req.params.id,req.body.userId]);res.json({ok:true});});
app.get('/chats/:id/messages',auth,async(req,res)=>{const r=await pool.query('SELECT m.*,u.display_name sender_name FROM messages m JOIN users u ON u.id=m.sender_id JOIN chat_members cm ON cm.chat_id=m.chat_id WHERE m.chat_id=$1 AND cm.user_id=$2 ORDER BY m.created_at ASC LIMIT 200',[req.params.id,req.user.id]);res.json(r.rows);});
app.post('/chats/:id/messages',auth,async(req,res)=>{try{
 const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[req.params.id,req.user.id]);if(!member.rowCount)return res.status(403).json({error:'not_member'});
 const body=String(req.body?.body||'').trim();if(!body)return res.status(400).json({error:'empty_message'});
 const r=await pool.query('INSERT INTO messages(chat_id,sender_id,body,message_type,media_url) VALUES($1,$2,$3,$4,$5) RETURNING *',[req.params.id,req.user.id,body,req.body?.type||'text',req.body?.mediaUrl||null]);
 io.to('chat:'+req.params.id).emit('message',r.rows[0]);res.json(r.rows[0]);
}catch(e){console.error(e);res.status(500).json({error:'message_failed'});}});

io.use((s,next)=>{try{s.user=jwt.verify(s.handshake.auth?.token||'',SECRET);next();}catch{next(new Error('unauthorized'));}});
io.on('connection',s=>{s.on('presence',v=>s.broadcast.emit('presence',{userId:s.user.id,online:!!v}));s.on('joinChat',id=>s.join('chat:'+id));s.on('message',async m=>{try{const member=await pool.query('SELECT 1 FROM chat_members WHERE chat_id=$1 AND user_id=$2',[m.chatId,s.user.id]);if(!member.rowCount)return;const r=await pool.query('INSERT INTO messages(chat_id,sender_id,body,message_type,media_url) VALUES($1,$2,$3,$4,$5) RETURNING *',[m.chatId,s.user.id,String(m.body||''),m.type||'text',m.mediaUrl||null]);io.to('chat:'+m.chatId).emit('message',r.rows[0]);}catch(e){s.emit('error',{error:'message_failed'});}});s.on('disconnect',()=>s.broadcast.emit('presence',{userId:s.user.id,online:false}));});

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
    'CREATE INDEX IF NOT EXISTS idx_messages_chat_created ON messages(chat_id,created_at)',
    'CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id)'
  ];
  for(const sql of statements){
    try{await pool.query(sql);}
    catch(e){console.error('migration failed:',sql.slice(0,100),e);throw e;}
  }
  console.log('database schema ready');
}
migrate().then(()=>server.listen(process.env.PORT||3000,()=>console.log('vibe<3 server ready'))).catch(e=>{console.error(e);process.exit(1);});
