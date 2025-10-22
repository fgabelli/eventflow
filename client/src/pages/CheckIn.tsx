import { useState, useEffect } from 'react';
import { Html5QrcodeScanner } from 'html5-qrcode';
import { checkInByQRCode } from '@/services/attendees';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { CheckCircle2, XCircle, QrCode } from 'lucide-react';
import { toast } from 'sonner';

export default function CheckIn() {
  const [scanning, setScanning] = useState(false);
  const [lastScan, setLastScan] = useState<any>(null);
  const [scanResult, setScanResult] = useState<'success' | 'error' | null>(null);

  useEffect(() => {
    const scanner = new Html5QrcodeScanner(
      'qr-reader',
      {
        fps: 10,
        qrbox: { width: 250, height: 250 },
      },
      false
    );

    scanner.render(onScanSuccess, onScanError);
    setScanning(true);

    return () => {
      scanner.clear();
    };
  }, []);

  const onScanSuccess = async (decodedText: string) => {
    try {
      const attendee = await checkInByQRCode(decodedText);
      setLastScan(attendee);
      setScanResult('success');
      toast.success(`Check-in completato per ${attendee.name}`);
      
      // Reset after 3 seconds
      setTimeout(() => {
        setScanResult(null);
        setLastScan(null);
      }, 3000);
    } catch (error: any) {
      setScanResult('error');
      toast.error(error.message || 'Errore durante il check-in');
      
      setTimeout(() => {
        setScanResult(null);
      }, 3000);
    }
  };

  const onScanError = (error: any) => {
    // Ignore scan errors (happens continuously while scanning)
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Check-in Scanner</h1>
        <p className="text-muted-foreground mt-2">
          Scansiona il QR code del partecipante per effettuare il check-in
        </p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Scanner QR Code</CardTitle>
            <CardDescription>
              Posiziona il QR code davanti alla fotocamera
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div id="qr-reader" className="w-full"></div>
            {!scanning && (
              <div className="flex flex-col items-center justify-center py-12">
                <QrCode className="h-16 w-16 text-muted-foreground mb-4" />
                <p className="text-muted-foreground">Inizializzazione scanner...</p>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Risultato Scansione</CardTitle>
            <CardDescription>
              Informazioni sull'ultimo check-in effettuato
            </CardDescription>
          </CardHeader>
          <CardContent>
            {!lastScan && !scanResult && (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <QrCode className="h-16 w-16 text-muted-foreground mb-4" />
                <p className="text-muted-foreground">
                  In attesa di scansione...
                </p>
              </div>
            )}

            {scanResult === 'success' && lastScan && (
              <Alert className="border-green-500 bg-green-50 dark:bg-green-950">
                <CheckCircle2 className="h-4 w-4 text-green-600" />
                <AlertDescription>
                  <div className="space-y-2">
                    <p className="font-semibold text-green-900 dark:text-green-100">
                      Check-in completato con successo!
                    </p>
                    <div className="space-y-1 text-sm">
                      <p>
                        <strong>Nome:</strong> {lastScan.name}
                      </p>
                      <p>
                        <strong>Email:</strong> {lastScan.email}
                      </p>
                      {lastScan.phone && (
                        <p>
                          <strong>Telefono:</strong> {lastScan.phone}
                        </p>
                      )}
                      <p>
                        <strong>Orario:</strong>{' '}
                        {new Date(lastScan.checked_in_at).toLocaleString('it-IT')}
                      </p>
                    </div>
                  </div>
                </AlertDescription>
              </Alert>
            )}

            {scanResult === 'error' && (
              <Alert variant="destructive">
                <XCircle className="h-4 w-4" />
                <AlertDescription>
                  <p className="font-semibold">Errore durante il check-in</p>
                  <p className="text-sm mt-1">
                    QR code non valido o partecipante già registrato
                  </p>
                </AlertDescription>
              </Alert>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Statistiche Check-in</CardTitle>
          <CardDescription>
            Riepilogo dei check-in di oggi
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">Totale Check-in</p>
              <p className="text-2xl font-bold">0</p>
            </div>
            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">Ultima ora</p>
              <p className="text-2xl font-bold">0</p>
            </div>
            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">In attesa</p>
              <p className="text-2xl font-bold">0</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

