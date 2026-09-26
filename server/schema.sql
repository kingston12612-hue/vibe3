CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 username TEXT UNIQUE NOT NULL,
 email TEXT UNIQUE NOT NULL,
 display_name TEXT NOT NULL,
 password_hash TEXT NOT NULL,
 avatar_url TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS chats(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 title TEXT,
 is_group BOOLEAN NOT NULL DEFAULT false,
 created_by UUID REFERENCES users(id) ON DELETE SET NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS chat_members(
 chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(chat_id,user_id)
);
CREATE TABLE IF NOT EXISTS messages(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
 sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 body TEXT NOT NULL DEFAULT '',
 message_type TEXT NOT NULL DEFAULT 'text',
 media_url TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_chat_created ON messages(chat_id,created_at);
CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id);