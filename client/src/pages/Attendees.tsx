import { useState, useEffect } from 'react';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import { getAttendees, deleteAttendee, getAttendeeQRCode } from '@/services/attendees';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Plus, MoreVertical, Edit, Trash2, QrCode, Users, Download } from 'lucide-react';
import { useLocation } from 'wouter';
import { toast } from 'sonner';

export default function Attendees() {
  const { user } = useSupabaseAuth();
  const [, setLocation] = useLocation();
  const [attendees, setAttendees] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [qrDialogOpen, setQrDialogOpen] = useState(false);
  const [selectedQR, setSelectedQR] = useState<string | null>(null);

  useEffect(() => {
    loadAttendees();
  }, [user]);

  const loadAttendees = async () => {
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

      const data = await getAttendees(userData.organization_id);
      setAttendees(data);
    } catch (error: any) {
      toast.error(error.message || 'Errore nel caricamento dei partecipanti');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Sei sicuro di voler eliminare questo partecipante?')) return;

    try {
      await deleteAttendee(id);
      toast.success('Partecipante eliminato con successo');
      loadAttendees();
    } catch (error: any) {
      toast.error(error.message || 'Errore nell\'eliminazione del partecipante');
    }
  };

  const handleShowQR = async (attendeeId: string) => {
    try {
      const qrCode = await getAttendeeQRCode(attendeeId);
      setSelectedQR(qrCode);
      setQrDialogOpen(true);
    } catch (error: any) {
      toast.error(error.message || 'Errore nel caricamento del QR code');
    }
  };

  const handleDownloadQR = () => {
    if (!selectedQR) return;

    const link = document.createElement('a');
    link.download = 'qr-code.png';
    link.href = selectedQR;
    link.click();
  };

  const getStatusBadge = (status: string) => {
    const variants: Record<string, 'default' | 'secondary' | 'destructive' | 'outline'> = {
      registered: 'secondary',
      checked_in: 'default',
      cancelled: 'destructive',
    };

    const labels: Record<string, string> = {
      registered: 'Registrato',
      checked_in: 'Check-in',
      cancelled: 'Annullato',
    };

    return (
      <Badge variant={variants[status] || 'default'}>
        {labels[status] || status}
      </Badge>
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Partecipanti</h1>
          <p className="text-muted-foreground mt-2">
            Gestisci i partecipanti ai tuoi eventi
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => setLocation('/attendees/import')}>
            <Download className="mr-2 h-4 w-4" />
            Importa
          </Button>
          <Button onClick={() => setLocation('/attendees/new')}>
            <Plus className="mr-2 h-4 w-4" />
            Nuovo Partecipante
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Lista Partecipanti</CardTitle>
          <CardDescription>
            Tutti i partecipanti registrati ai tuoi eventi
          </CardDescription>
        </CardHeader>
        <CardContent>
          {attendees.length === 0 ? (
            <div className="text-center py-12">
              <Users className="mx-auto h-12 w-12 text-muted-foreground" />
              <h3 className="mt-4 text-lg font-semibold">Nessun partecipante</h3>
              <p className="text-muted-foreground mt-2">
                Inizia aggiungendo il tuo primo partecipante
              </p>
              <Button onClick={() => setLocation('/attendees/new')} className="mt-4">
                <Plus className="mr-2 h-4 w-4" />
                Aggiungi Partecipante
              </Button>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nome</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Telefono</TableHead>
                  <TableHead>Stato</TableHead>
                  <TableHead>Data Registrazione</TableHead>
                  <TableHead className="text-right">Azioni</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {attendees.map((attendee) => (
                  <TableRow key={attendee.id}>
                    <TableCell className="font-medium">{attendee.name}</TableCell>
                    <TableCell>{attendee.email}</TableCell>
                    <TableCell>{attendee.phone || '-'}</TableCell>
                    <TableCell>{getStatusBadge(attendee.status)}</TableCell>
                    <TableCell>
                      {new Date(attendee.registered_at).toLocaleDateString('it-IT')}
                    </TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            onClick={() => setLocation(`/attendees/${attendee.id}`)}
                          >
                            <Edit className="mr-2 h-4 w-4" />
                            Modifica
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => handleShowQR(attendee.id)}>
                            <QrCode className="mr-2 h-4 w-4" />
                            Mostra QR Code
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleDelete(attendee.id)}
                            className="text-destructive"
                          >
                            <Trash2 className="mr-2 h-4 w-4" />
                            Elimina
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Dialog open={qrDialogOpen} onOpenChange={setQrDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>QR Code Partecipante</DialogTitle>
            <DialogDescription>
              Scansiona questo QR code per effettuare il check-in
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col items-center gap-4 py-4">
            {selectedQR && (
              <>
                <img src={selectedQR} alt="QR Code" className="w-64 h-64" />
                <Button onClick={handleDownloadQR} variant="outline">
                  <Download className="mr-2 h-4 w-4" />
                  Scarica QR Code
                </Button>
              </>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

