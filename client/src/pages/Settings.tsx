import { useState, useEffect } from 'react';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { toast } from 'sonner';
import { DashboardLayout } from '@/components/layout/DashboardLayout';

export default function Settings() {
  const { user } = useSupabaseAuth();
  const [loading, setLoading] = useState(false);
  const [organizationName, setOrganizationName] = useState('');
  const [userName, setUserName] = useState('');
  const [userEmail, setUserEmail] = useState('');

  useEffect(() => {
    if (user) {
      loadSettings();
    }
  }, [user]);

  const loadSettings = async () => {
    if (!user) return;

    try {
      // Carica dati organizzazione
      const { data: org, error: orgError } = await supabase
        .from('organizations')
        .select('name')
        .eq('id', user.id)
        .single();

      if (orgError) throw orgError;
      if (org) setOrganizationName(org.name);

      // Carica dati utente
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('name, email')
        .eq('id', user.id)
        .single();

      if (userError) throw userError;
      if (userData) {
        setUserName(userData.name || '');
        setUserEmail(userData.email || '');
      }
    } catch (error: any) {
      console.error('Error loading settings:', error);
      toast.error('Errore nel caricamento delle impostazioni');
    }
  };

  const handleSaveOrganization = async () => {
    if (!user) return;
    setLoading(true);

    try {
      const { error } = await supabase
        .from('organizations')
        .update({ name: organizationName })
        .eq('id', user.id);

      if (error) throw error;
      toast.success('Nome organizzazione aggiornato con successo');
    } catch (error: any) {
      console.error('Error updating organization:', error);
      toast.error('Errore nell\'aggiornamento del nome organizzazione');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveProfile = async () => {
    if (!user) return;
    setLoading(true);

    try {
      const { error } = await supabase
        .from('users')
        .update({ name: userName })
        .eq('id', user.id);

      if (error) throw error;
      toast.success('Profilo aggiornato con successo');
    } catch (error: any) {
      console.error('Error updating profile:', error);
      toast.error('Errore nell\'aggiornamento del profilo');
    } finally {
      setLoading(false);
    }
  };

  return (
    <DashboardLayout>
      <div className="container max-w-4xl py-8">
        <h1 className="text-3xl font-bold mb-6">Impostazioni</h1>

        <Tabs defaultValue="organization" className="w-full">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="organization">Organizzazione</TabsTrigger>
            <TabsTrigger value="profile">Profilo</TabsTrigger>
          </TabsList>

          <TabsContent value="organization">
            <Card>
              <CardHeader>
                <CardTitle>Impostazioni Organizzazione</CardTitle>
                <CardDescription>
                  Gestisci le informazioni della tua organizzazione
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="org-name">Nome Organizzazione</Label>
                  <Input
                    id="org-name"
                    value={organizationName}
                    onChange={(e) => setOrganizationName(e.target.value)}
                    placeholder="Nome della tua organizzazione"
                  />
                </div>

                <Button onClick={handleSaveOrganization} disabled={loading}>
                  {loading ? 'Salvataggio...' : 'Salva Modifiche'}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="profile">
            <Card>
              <CardHeader>
                <CardTitle>Profilo Utente</CardTitle>
                <CardDescription>
                  Gestisci le tue informazioni personali
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="user-name">Nome</Label>
                  <Input
                    id="user-name"
                    value={userName}
                    onChange={(e) => setUserName(e.target.value)}
                    placeholder="Il tuo nome"
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="user-email">Email</Label>
                  <Input
                    id="user-email"
                    value={userEmail}
                    disabled
                    placeholder="La tua email"
                  />
                  <p className="text-sm text-muted-foreground">
                    L'email non può essere modificata
                  </p>
                </div>

                <Button onClick={handleSaveProfile} disabled={loading}>
                  {loading ? 'Salvataggio...' : 'Salva Modifiche'}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  );
}

