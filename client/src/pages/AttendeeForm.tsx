import { useState, useEffect } from 'react';
import { useLocation, useRoute } from 'wouter';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import { createAttendee, updateAttendee, getAttendeeById } from '@/services/attendees';
import { getEvents } from '@/services/events';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { toast } from 'sonner';
import { ArrowLeft } from 'lucide-react';

export default function AttendeeForm() {
  const { user } = useSupabaseAuth();
  const [, setLocation] = useLocation();
  const [, params] = useRoute('/attendees/:id');
  const isEdit = params?.id && params.id !== 'new';

  const [loading, setLoading] = useState(false);
  const [events, setEvents] = useState<any[]>([]);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    event_id: '',
    status: 'registered',
  });

  useEffect(() => {
    loadEvents();
    if (isEdit) {
      loadAttendee();
    }
  }, [isEdit]);

  const loadEvents = async () => {
    if (!user) return;

    try {
      const { data: userData } = await supabase
        .from('users')
        .select('organization_id')
        .eq('email', user.email!)
        .single();

      if (userData?.organization_id) {
        const eventsData = await getEvents(userData.organization_id);
        setEvents(eventsData);
      }
    } catch (error: any) {
      console.error('Error loading events:', error);
    }
  };

  const loadAttendee = async () => {
    try {
      const attendee = await getAttendeeById(params!.id);
      setFormData({
        name: attendee.name,
        email: attendee.email,
        phone: attendee.phone || '',
        event_id: attendee.event_id || '',
        status: attendee.status,
      });
    } catch (error: any) {
      toast.error(error.message || 'Errore nel caricamento del partecipante');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    try {
      setLoading(true);

      const { data: userData } = await supabase
        .from('users')
        .select('organization_id')
        .eq('email', user.email!)
        .single();

      if (!userData?.organization_id) {
        toast.error('Organizzazione non trovata');
        return;
      }

      const attendeeData = {
        ...formData,
        event_id: formData.event_id || null,
        phone: formData.phone || null,
        organization_id: userData.organization_id,
      };

      if (isEdit) {
        await updateAttendee(params!.id, attendeeData);
        toast.success('Partecipante aggiornato con successo');
      } else {
        await createAttendee(attendeeData);
        toast.success('Partecipante creato con successo');
      }

      setLocation('/attendees');
    } catch (error: any) {
      toast.error(error.message || 'Errore nel salvataggio del partecipante');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={() => setLocation('/attendees')}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <div>
          <h1 className="text-3xl font-bold">
            {isEdit ? 'Modifica Partecipante' : 'Nuovo Partecipante'}
          </h1>
          <p className="text-muted-foreground mt-2">
            {isEdit ? 'Aggiorna i dettagli del partecipante' : 'Aggiungi un nuovo partecipante'}
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Dettagli Partecipante</CardTitle>
          <CardDescription>
            Inserisci le informazioni del partecipante
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="name">Nome Completo *</Label>
              <Input
                id="name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="email">Email *</Label>
              <Input
                id="email"
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="phone">Telefono</Label>
              <Input
                id="phone"
                type="tel"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="event_id">Evento</Label>
              <Select
                value={formData.event_id}
                onValueChange={(value) => setFormData({ ...formData, event_id: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Seleziona un evento" />
                </SelectTrigger>
                <SelectContent>
                  {events.map((event) => (
                    <SelectItem key={event.id} value={event.id}>
                      {event.title} - {event.date}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="status">Stato *</Label>
              <Select
                value={formData.status}
                onValueChange={(value) => setFormData({ ...formData, status: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="registered">Registrato</SelectItem>
                  <SelectItem value="checked_in">Check-in Effettuato</SelectItem>
                  <SelectItem value="cancelled">Annullato</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex gap-4">
              <Button type="submit" disabled={loading}>
                {loading ? 'Salvataggio...' : isEdit ? 'Aggiorna Partecipante' : 'Crea Partecipante'}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => setLocation('/attendees')}
              >
                Annulla
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

