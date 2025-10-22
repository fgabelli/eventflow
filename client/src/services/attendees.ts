import { supabase } from '@/lib/supabase';
import type { Database } from '../../../shared/database.types';
import QRCode from 'qrcode';

type Attendee = Database['public']['Tables']['attendees']['Row'];
type InsertAttendee = Database['public']['Tables']['attendees']['Insert'];
type UpdateAttendee = Database['public']['Tables']['attendees']['Update'];

export async function getAttendees(organizationId: string, eventId?: string) {
  let query = supabase
    .from('attendees')
    .select('*')
    .eq('organization_id', organizationId);

  if (eventId) {
    query = query.eq('event_id', eventId);
  }

  const { data, error } = await query.order('registered_at', { ascending: false });

  if (error) throw error;
  return data;
}

export async function getAttendeeById(id: string) {
  const { data, error } = await supabase
    .from('attendees')
    .select('*')
    .eq('id', id)
    .single();

  if (error) throw error;
  return data;
}

export async function getAttendeeByQRCode(qrCode: string) {
  const { data, error } = await supabase
    .from('attendees')
    .select('*')
    .eq('qr_code', qrCode)
    .single();

  if (error) throw error;
  return data;
}

export async function createAttendee(attendee: Omit<InsertAttendee, 'qr_code'>) {
  // Generate unique QR code for the attendee
  const qrCodeData = `ATTENDEE:${Date.now()}:${Math.random().toString(36).substring(7)}`;
  const qrCodeImage = await QRCode.toDataURL(qrCodeData);

  const { data, error } = await supabase
    .from('attendees')
    .insert({
      ...attendee,
      qr_code: qrCodeData,
    })
    .select()
    .single();

  if (error) throw error;
  return { ...data, qr_code_image: qrCodeImage };
}

export async function updateAttendee(id: string, attendee: UpdateAttendee) {
  const { data, error } = await supabase
    .from('attendees')
    .update(attendee)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteAttendee(id: string) {
  const { error } = await supabase.from('attendees').delete().eq('id', id);

  if (error) throw error;
}

export async function checkInAttendee(id: string) {
  const { data, error } = await supabase
    .from('attendees')
    .update({
      status: 'checked_in',
      checked_in_at: new Date().toISOString(),
    })
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function checkInByQRCode(qrCode: string) {
  const attendee = await getAttendeeByQRCode(qrCode);
  return await checkInAttendee(attendee.id);
}

export async function getAttendeeQRCode(attendeeId: string) {
  const attendee = await getAttendeeById(attendeeId);
  const qrCodeImage = await QRCode.toDataURL(attendee.qr_code);
  return qrCodeImage;
}

export async function bulkImportAttendees(
  attendees: Array<Omit<InsertAttendee, 'qr_code'>>,
  onProgress?: (current: number, total: number) => void
) {
  const results = [];
  
  for (let i = 0; i < attendees.length; i++) {
    try {
      const result = await createAttendee(attendees[i]);
      results.push({ success: true, data: result });
      onProgress?.(i + 1, attendees.length);
    } catch (error) {
      results.push({ success: false, error, data: attendees[i] });
    }
  }

  return results;
}

