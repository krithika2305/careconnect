-- Chat Messages Schema for Caregiver-Doctor Messaging
-- This table enables secure messaging between caregivers and assigned doctors

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  patient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Caregivers can read messages where they are sender or receiver
-- and the patient is mapped to them via caregiver_patient_mapping
CREATE POLICY "Caregivers can read their messages"
  ON public.chat_messages
  FOR SELECT
  USING (
    auth.uid() = sender_id
    OR auth.uid() = receiver_id
  );

-- Caregivers can insert messages where they are the sender
-- and the patient is mapped to them
CREATE POLICY "Caregivers can send messages"
  ON public.chat_messages
  FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.caregiver_patient_mapping
      WHERE caregiver_id = auth.uid()
      AND patient_id = chat_messages.patient_id
    )
  );

-- Caregivers can update is_read flag for messages sent to them
CREATE POLICY "Caregivers can mark messages as read"
  ON public.chat_messages
  FOR UPDATE
  USING (
    auth.uid() = receiver_id
  )
  WITH CHECK (
    auth.uid() = receiver_id
    AND is_read = TRUE
  );

-- Doctors can read messages where they are sender or receiver
CREATE POLICY "Doctors can read their messages"
  ON public.chat_messages
  FOR SELECT
  USING (
    auth.uid() = sender_id
    OR auth.uid() = receiver_id
  );

-- Doctors can insert messages where they are the sender
CREATE POLICY "Doctors can send messages"
  ON public.chat_messages
  FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = chat_messages.patient_id
    )
  );

-- Doctors can update is_read flag for messages sent to them
CREATE POLICY "Doctors can mark messages as read"
  ON public.chat_messages
  FOR UPDATE
  USING (
    auth.uid() = receiver_id
  )
  WITH CHECK (
    auth.uid() = receiver_id
    AND is_read = TRUE
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_id ON public.chat_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_patient_id ON public.chat_messages(patient_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- Enable Realtime for chat_messages table
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- Function to get conversation between two users for a patient
CREATE OR REPLACE FUNCTION public.get_conversation(
  p_user_id UUID,
  p_other_user_id UUID,
  p_patient_id UUID
)
RETURNS TABLE (
  id UUID,
  sender_id UUID,
  receiver_id UUID,
  patient_id UUID,
  message TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    id, sender_id, receiver_id, patient_id, message, is_read, created_at
  FROM public.chat_messages
  WHERE (
    (sender_id = p_user_id AND receiver_id = p_other_user_id)
    OR (sender_id = p_other_user_id AND receiver_id = p_user_id)
  )
  AND patient_id = p_patient_id
  ORDER BY created_at ASC;
$$;

-- Function to get unread message count for a user
CREATE OR REPLACE FUNCTION public.get_unread_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)
  FROM public.chat_messages
  WHERE receiver_id = p_user_id
  AND is_read = FALSE;
$$;
