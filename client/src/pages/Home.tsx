import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Calendar, Users, Mail, TrendingUp } from 'lucide-react';

export default function Home() {
  const { user } = useSupabaseAuth();

  const stats = [
    {
      title: 'Eventi Attivi',
      value: '0',
      description: 'Eventi pubblicati',
      icon: Calendar,
      color: 'text-blue-600',
    },
    {
      title: 'Partecipanti',
      value: '0',
      description: 'Registrazioni totali',
      icon: Users,
      color: 'text-green-600',
    },
    {
      title: 'Check-in',
      value: '0',
      description: 'Check-in completati',
      icon: TrendingUp,
      color: 'text-purple-600',
    },
    {
      title: 'Email Inviate',
      value: '0',
      description: 'Campagne attive',
      icon: Mail,
      color: 'text-orange-600',
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground mt-2">
          Benvenuto, {user?.user_metadata?.name || user?.email}
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <Card key={stat.title}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{stat.title}</CardTitle>
                <Icon className={`h-4 w-4 ${stat.color}`} />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
                <p className="text-xs text-muted-foreground">{stat.description}</p>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Inizia con EventFlow</CardTitle>
          <CardDescription>
            Crea il tuo primo evento e inizia a gestire i partecipanti
          </CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            EventFlow è la tua piattaforma completa per la gestione eventi. Crea eventi,
            gestisci partecipanti, genera QR code e invia campagne email personalizzate.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
