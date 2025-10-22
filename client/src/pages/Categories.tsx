import { useState, useEffect } from 'react';
import { useSupabaseAuth } from '@/contexts/SupabaseAuthContext';
import { supabase } from '@/lib/supabase';
import {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  createSubcategory,
  deleteSubcategory,
} from '@/services/categories';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { Plus, Trash2, Tags } from 'lucide-react';
import { toast } from 'sonner';

export default function Categories() {
  const { user } = useSupabaseAuth();
  const [categories, setCategories] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [subDialogOpen, setSubDialogOpen] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newSubcategoryName, setNewSubcategoryName] = useState('');

  useEffect(() => {
    loadCategories();
  }, [user]);

  const loadCategories = async () => {
    if (!user) return;

    try {
      setLoading(true);

      const { data: userData } = await supabase
        .from('users')
        .select('organization_id')
        .eq('id', user.id)
        .single();

      if (!userData?.organization_id) {
        toast.error('Organizzazione non trovata');
        return;
      }

      const data = await getCategories(userData.organization_id);
      setCategories(data);
    } catch (error: any) {
      toast.error(error.message || 'Errore nel caricamento delle categorie');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !newCategoryName.trim()) return;

    try {
      const { data: userData } = await supabase
        .from('users')
        .select('organization_id')
        .eq('id', user.id)
        .single();

      if (!userData?.organization_id) {
        toast.error('Organizzazione non trovata');
        return;
      }

      await createCategory({
        name: newCategoryName,
        organization_id: userData.organization_id,
        created_by: user.id,
      });

      toast.success('Categoria creata con successo');
      setNewCategoryName('');
      setDialogOpen(false);
      loadCategories();
    } catch (error: any) {
      toast.error(error.message || 'Errore nella creazione della categoria');
    }
  };

  const handleDeleteCategory = async (id: string) => {
    if (!confirm('Sei sicuro di voler eliminare questa categoria?')) return;

    try {
      await deleteCategory(id);
      toast.success('Categoria eliminata con successo');
      loadCategories();
    } catch (error: any) {
      toast.error(error.message || 'Errore nell\'eliminazione della categoria');
    }
  };

  const handleCreateSubcategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCategory || !newSubcategoryName.trim()) return;

    try {
      await createSubcategory({
        name: newSubcategoryName,
        category_id: selectedCategory,
      });

      toast.success('Sottocategoria creata con successo');
      setNewSubcategoryName('');
      setSubDialogOpen(false);
      setSelectedCategory(null);
      loadCategories();
    } catch (error: any) {
      toast.error(error.message || 'Errore nella creazione della sottocategoria');
    }
  };

  const handleDeleteSubcategory = async (id: string) => {
    if (!confirm('Sei sicuro di voler eliminare questa sottocategoria?')) return;

    try {
      await deleteSubcategory(id);
      toast.success('Sottocategoria eliminata con successo');
      loadCategories();
    } catch (error: any) {
      toast.error(error.message || 'Errore nell\'eliminazione della sottocategoria');
    }
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
          <h1 className="text-3xl font-bold">Categorie</h1>
          <p className="text-muted-foreground mt-2">
            Gestisci le categorie e sottocategorie per organizzare i tuoi eventi
          </p>
        </div>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="mr-2 h-4 w-4" />
              Nuova Categoria
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Crea Nuova Categoria</DialogTitle>
              <DialogDescription>
                Inserisci il nome della nuova categoria
              </DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateCategory} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="category-name">Nome Categoria</Label>
                <Input
                  id="category-name"
                  value={newCategoryName}
                  onChange={(e) => setNewCategoryName(e.target.value)}
                  placeholder="Es: VIP, Staff, Stampa..."
                  required
                />
              </div>
              <div className="flex gap-2">
                <Button type="submit">Crea Categoria</Button>
                <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                  Annulla
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {categories.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <Tags className="mx-auto h-12 w-12 text-muted-foreground" />
            <h3 className="mt-4 text-lg font-semibold">Nessuna categoria</h3>
            <p className="text-muted-foreground mt-2">
              Inizia creando la tua prima categoria
            </p>
            <Button onClick={() => setDialogOpen(true)} className="mt-4">
              <Plus className="mr-2 h-4 w-4" />
              Crea Categoria
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {categories.map((category) => (
            <Card key={category.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{category.name}</CardTitle>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleDeleteCategory(category.id)}
                  >
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
                <CardDescription>
                  {category.subcategories?.length || 0} sottocategorie
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {category.subcategories && category.subcategories.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {category.subcategories.map((sub: any) => (
                      <Badge key={sub.id} variant="secondary" className="gap-1">
                        {sub.name}
                        <button
                          onClick={() => handleDeleteSubcategory(sub.id)}
                          className="ml-1 hover:text-destructive"
                        >
                          ×
                        </button>
                      </Badge>
                    ))}
                  </div>
                )}
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full"
                  onClick={() => {
                    setSelectedCategory(category.id);
                    setSubDialogOpen(true);
                  }}
                >
                  <Plus className="mr-2 h-3 w-3" />
                  Aggiungi Sottocategoria
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Dialog open={subDialogOpen} onOpenChange={setSubDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Crea Nuova Sottocategoria</DialogTitle>
            <DialogDescription>
              Inserisci il nome della nuova sottocategoria
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleCreateSubcategory} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="subcategory-name">Nome Sottocategoria</Label>
              <Input
                id="subcategory-name"
                value={newSubcategoryName}
                onChange={(e) => setNewSubcategoryName(e.target.value)}
                placeholder="Es: Gold, Silver, Bronze..."
                required
              />
            </div>
            <div className="flex gap-2">
              <Button type="submit">Crea Sottocategoria</Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  setSubDialogOpen(false);
                  setSelectedCategory(null);
                }}
              >
                Annulla
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

