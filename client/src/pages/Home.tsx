import { useState, useEffect } from 'react';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Calendar, Users, Mail, TrendingUp } from 'lucide-react';
import { toast } from 'sonner';

export default function Home() {
  const { user } = useSupabaseAuth();
  const [stats, setStats] = useState({
    activeEvents: 0,
    totalAttendees: 0,
    totalCheckIns: 0,
    emailsSent: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStats();
  }, [user]);

  const loadStats = async () => {
    if (!user) return;

    try {
      const { data: userData } = await supabase
        .from('users')
        .select('organization_id')
        .eq('email', user.email!)
        .single();

      if (!userData?.organization_id) return;

      const [eventsData, attendeesData, campaignsData] = await Promise.all([
        supabase
          .from('events')
          .select('status')
          .eq('organization_id', userData.organization_id),
        supabase
          .from('attendees')
          .select('status')
          .eq('organization_id', userData.organization_id),
        supabase
          .from('email_campaigns')
          .select('sent_count')
          .eq('organization_id', userData.organization_id),
      ]);

      setStats({
        activeEvents: eventsData.data?.filter((e) => e.status === 'published').length || 0,
        totalAttendees: attendeesData.data?.length || 0,
        totalCheckIns: attendeesData.data?.filter((a) => a.status === 'checked_in').length || 0,
        emailsSent: campaignsData.data?.reduce((sum, c) => sum + (c.sent_count || 0), 0) || 0,
      });
    } catch (error: any) {
      console.error('Error loading stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const statsDisplay = [
    {
      title: 'Eventi Attivi',
      value: stats.activeEvents.toString(),
      description: 'Eventi pubblicati',
      icon: Calendar,
      color: 'text-blue-600',
    },
    {
      title: 'Partecipanti',
      value: stats.totalAttendees.toString(),
      description: 'Registrazioni totali',
      icon: Users,
      color: 'text-green-600',
    },
    {
      title: 'Check-in',
      value: stats.totalCheckIns.toString(),
      description: 'Check-in completati',
      icon: TrendingUp,
      color: 'text-purple-600',
    },
    {
      title: 'Email Inviate',
      value: stats.emailsSent.toString(),
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
        {statsDisplay.map((stat) => {
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
