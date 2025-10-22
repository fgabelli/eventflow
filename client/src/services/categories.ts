import { supabase } from '@/lib/supabase';
import type { Database } from '../../../shared/database.types';

type Category = Database['public']['Tables']['categories']['Row'];
type InsertCategory = Database['public']['Tables']['categories']['Insert'];
type UpdateCategory = Database['public']['Tables']['categories']['Update'];

type Subcategory = Database['public']['Tables']['subcategories']['Row'];
type InsertSubcategory = Database['public']['Tables']['subcategories']['Insert'];
type UpdateSubcategory = Database['public']['Tables']['subcategories']['Update'];

export async function getCategories(organizationId: string) {
  const { data, error } = await supabase
    .from('categories')
    .select('*, subcategories(*)')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

export async function getCategoryById(id: string) {
  const { data, error } = await supabase
    .from('categories')
    .select('*, subcategories(*)')
    .eq('id', id)
    .single();

  if (error) throw error;
  return data;
}

export async function createCategory(category: InsertCategory) {
  const { data, error } = await supabase
    .from('categories')
    .insert(category)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateCategory(id: string, category: UpdateCategory) {
  const { data, error } = await supabase
    .from('categories')
    .update(category)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteCategory(id: string) {
  const { error } = await supabase.from('categories').delete().eq('id', id);

  if (error) throw error;
}

export async function getSubcategories(categoryId: string) {
  const { data, error } = await supabase
    .from('subcategories')
    .select('*')
    .eq('category_id', categoryId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

export async function createSubcategory(subcategory: InsertSubcategory) {
  const { data, error } = await supabase
    .from('subcategories')
    .insert(subcategory)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateSubcategory(id: string, subcategory: UpdateSubcategory) {
  const { data, error } = await supabase
    .from('subcategories')
    .update(subcategory)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteSubcategory(id: string) {
  const { error } = await supabase.from('subcategories').delete().eq('id', id);

  if (error) throw error;
}

