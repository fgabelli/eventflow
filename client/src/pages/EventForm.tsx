import { useState, useEffect } from 'react';
import { useLocation, useRoute } from 'wouter';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import { createEvent, updateEvent, getEventById } from '@/services/events';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { toast } from 'sonner';
import { ArrowLeft } from 'lucide-react';

export default function EventForm() {
  const { user } = useSupabaseAuth();
  const [, setLocation] = useLocation();
  const [, params] = useRoute('/events/:id');
  const isEdit = params?.id && params.id !== 'new';

  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    date: '',
    start_time: '',
    end_time: '',
    location: '',
    capacity: '',
    status: 'draft',
  });

  useEffect(() => {
    if (isEdit) {
      loadEvent();
    }
  }, [isEdit]);

  const loadEvent = async () => {
    try {
      const event = await getEventById(params!.id);
      setFormData({
        title: event.title,
        description: event.description || '',
        date: event.date,
        start_time: event.start_time,
        end_time: event.end_time,
        location: event.location,
        capacity: event.capacity?.toString() || '',
        status: event.status,
      });
    } catch (error: any) {
      toast.error(error.message || 'Errore nel caricamento dell\'evento');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    try {
      setLoading(true);

      if (!user.email) {
        toast.error('Email utente non trovata');
        return;
      }

      const { data: userData } = await supabase
        .from('users')
        .select('id, organization_id')
        .eq('email', user.email)
        .single();

      if (!userData?.organization_id) {
        toast.error('Organizzazione non trovata');
        return;
      }

      const eventData = {
        ...formData,
        capacity: formData.capacity ? parseInt(formData.capacity) : null,
        organization_id: userData.organization_id,
        created_by: userData.id,
      };

      console.log('EventData to send:', eventData);
      console.log('UserData:', userData);

      if (isEdit) {
        await updateEvent(params!.id, eventData);
        toast.success('Evento aggiornato con successo');
      } else {
        await createEvent(eventData);
        toast.success('Evento creato con successo');
      }

      setLocation('/events');
    } catch (error: any) {
      toast.error(error.message || 'Errore nel salvataggio dell\'evento');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={() => setLocation('/events')}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <div>
          <h1 className="text-3xl font-bold">
            {isEdit ? 'Modifica Evento' : 'Nuovo Evento'}
          </h1>
          <p className="text-muted-foreground mt-2">
            {isEdit ? 'Aggiorna i dettagli dell\'evento' : 'Crea un nuovo evento'}
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Dettagli Evento</CardTitle>
          <CardDescription>
            Inserisci le informazioni principali dell'evento
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="title">Titolo *</Label>
              <Input
                id="title"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Descrizione</Label>
              <Textarea
                id="description"
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                rows={4}
              />
            </div>

            <div className="grid gap-4 md:grid-cols-3">
              <div className="space-y-2">
                <Label htmlFor="date">Data *</Label>
                <Input
                  id="date"
                  type="date"
                  value={formData.date}
                  onChange={(e) => setFormData({ ...formData, date: e.target.value })}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="start_time">Ora Inizio *</Label>
                <Input
                  id="start_time"
                  type="time"
                  value={formData.start_time}
                  onChange={(e) => setFormData({ ...formData, start_time: e.target.value })}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="end_time">Ora Fine *</Label>
                <Input
                  id="end_time"
                  type="time"
                  value={formData.end_time}
                  onChange={(e) => setFormData({ ...formData, end_time: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="location">Luogo *</Label>
              <Input
                id="location"
                value={formData.location}
                onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                required
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="capacity">Capacità</Label>
                <Input
                  id="capacity"
                  type="number"
                  min="0"
                  value={formData.capacity}
                  onChange={(e) => setFormData({ ...formData, capacity: e.target.value })}
                />
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
                    <SelectItem value="draft">Bozza</SelectItem>
                    <SelectItem value="published">Pubblicato</SelectItem>
                    <SelectItem value="completed">Completato</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="flex gap-4">
              <Button type="submit" disabled={loading}>
                {loading ? 'Salvataggio...' : isEdit ? 'Aggiorna Evento' : 'Crea Evento'}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => setLocation('/events')}
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

