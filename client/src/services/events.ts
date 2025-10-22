import { supabase } from '@/lib/supabase';
import type { Database } from '../../../shared/database.types';
import QRCode from 'qrcode';

type Event = Database['public']['Tables']['events']['Row'];
type InsertEvent = Database['public']['Tables']['events']['Insert'];
type UpdateEvent = Database['public']['Tables']['events']['Update'];

export async function getEvents(organizationId: string) {
  const { data, error } = await supabase
    .from('events')
    .select('*')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

export async function getEventById(id: string) {
  const { data, error } = await supabase
    .from('events')
    .select('*')
    .eq('id', id)
    .single();

  if (error) throw error;
  return data;
}

export async function createEvent(event: InsertEvent) {
  // Generate QR code for the event
  const qrCodeData = `${window.location.origin}/events/${event.public_url_id || 'new'}`;
  const qrCodeImage = await QRCode.toDataURL(qrCodeData);

  const { data, error } = await supabase
    .from('events')
    .insert({
      ...event,
      qr_code_image: qrCodeImage,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateEvent(id: string, event: UpdateEvent) {
  const { data, error } = await supabase
    .from('events')
    .update(event)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteEvent(id: string) {
  const { error } = await supabase.from('events').delete().eq('id', id);

  if (error) throw error;
}

export async function getEventStats(organizationId: string) {
  const { data: events, error } = await supabase
    .from('events')
    .select('status, registrations, check_ins')
    .eq('organization_id', organizationId);

  if (error) throw error;

  const stats = {
    total: events.length,
    published: events.filter((e) => e.status === 'published').length,
    draft: events.filter((e) => e.status === 'draft').length,
    totalRegistrations: events.reduce((sum, e) => sum + (e.registrations || 0), 0),
    totalCheckIns: events.reduce((sum, e) => sum + (e.check_ins || 0), 0),
  };

  return stats;
}

