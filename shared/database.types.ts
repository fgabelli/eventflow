export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "12.2.3 (519615d)"
  }
  public: {
    Tables: {
      attendees: {
        Row: {
          category_ids: string[] | null
          checked_in_at: string | null
          email: string
          event_id: string | null
          id: string
          name: string
          organization_id: string | null
          phone: string | null
          profile_data: Json | null
          qr_code: string
          registered_at: string | null
          status: string
          subcategory_ids: string[] | null
        }
        Insert: {
          category_ids?: string[] | null
          checked_in_at?: string | null
          email: string
          event_id?: string | null
          id?: string
          name: string
          organization_id?: string | null
          phone?: string | null
          profile_data?: Json | null
          qr_code: string
          registered_at?: string | null
          status?: string
          subcategory_ids?: string[] | null
        }
        Update: {
          category_ids?: string[] | null
          checked_in_at?: string | null
          email?: string
          event_id?: string | null
          id?: string
          name?: string
          organization_id?: string | null
          phone?: string | null
          profile_data?: Json | null
          qr_code?: string
          registered_at?: string | null
          status?: string
          subcategory_ids?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "attendees_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendees_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          created_at: string
          created_by: string
          id: string
          name: string
          organization_id: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          name: string
          organization_id: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "categories_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      email_campaigns: {
        Row: {
          click_count: number
          completed_at: string | null
          content: string
          created_at: string
          created_by: string
          description: string | null
          id: string
          linked_event_id: string | null
          open_count: number
          organization_id: string
          recipient_filter: Json | null
          scheduled_at: string | null
          sent_at: string | null
          sent_count: number
          status: string
          subject: string
          title: string
        }
        Insert: {
          click_count?: number
          completed_at?: string | null
          content: string
          created_at?: string
          created_by: string
          description?: string | null
          id?: string
          linked_event_id?: string | null
          open_count?: number
          organization_id: string
          recipient_filter?: Json | null
          scheduled_at?: string | null
          sent_at?: string | null
          sent_count?: number
          status: string
          subject: string
          title: string
        }
        Update: {
          click_count?: number
          completed_at?: string | null
          content?: string
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          linked_event_id?: string | null
          open_count?: number
          organization_id?: string
          recipient_filter?: Json | null
          scheduled_at?: string | null
          sent_at?: string | null
          sent_count?: number
          status?: string
          subject?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "email_campaigns_linked_event_id_fkey"
            columns: ["linked_event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "email_campaigns_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      email_logs: {
        Row: {
          campaign_id: string | null
          content: string
          id: string
          is_test: boolean | null
          recipients: string[] | null
          sent_at: string | null
          status: string
          subject: string
        }
        Insert: {
          campaign_id?: string | null
          content: string
          id?: string
          is_test?: boolean | null
          recipients?: string[] | null
          sent_at?: string | null
          status: string
          subject: string
        }
        Update: {
          campaign_id?: string | null
          content?: string
          id?: string
          is_test?: boolean | null
          recipients?: string[] | null
          sent_at?: string | null
          status?: string
          subject?: string
        }
        Relationships: [
          {
            foreignKeyName: "email_logs_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "email_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          banner: string | null
          capacity: number | null
          check_ins: number | null
          created_at: string
          created_by: string
          date: string
          description: string | null
          end_time: string
          form_fields: Json | null
          id: string
          location: string
          organization_id: string | null
          public_url_id: string | null
          qr_code_image: string | null
          registrations: number | null
          start_time: string
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          banner?: string | null
          capacity?: number | null
          check_ins?: number | null
          created_at?: string
          created_by: string
          date: string
          description?: string | null
          end_time: string
          form_fields?: Json | null
          id?: string
          location: string
          organization_id?: string | null
          public_url_id?: string | null
          qr_code_image?: string | null
          registrations?: number | null
          start_time: string
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          banner?: string | null
          capacity?: number | null
          check_ins?: number | null
          created_at?: string
          created_by?: string
          date?: string
          description?: string | null
          end_time?: string
          form_fields?: Json | null
          id?: string
          location?: string
          organization_id?: string | null
          public_url_id?: string | null
          qr_code_image?: string | null
          registrations?: number | null
          start_time?: string
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          email_configuration: Json | null
          id: string
          name: string
          owner_id: string | null
        }
        Insert: {
          created_at?: string
          email_configuration?: Json | null
          id?: string
          name: string
          owner_id?: string | null
        }
        Update: {
          created_at?: string
          email_configuration?: Json | null
          id?: string
          name?: string
          owner_id?: string | null
        }
        Relationships: []
      }
      subcategories: {
        Row: {
          category_id: string
          created_at: string
          id: string
          name: string
        }
        Insert: {
          category_id: string
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          category_id?: string
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "subcategories_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      user_permissions: {
        Row: {
          can_create_events: boolean | null
          can_delete_events: boolean | null
          can_edit_events: boolean | null
          can_manage_attendees: boolean | null
          can_manage_email_campaigns: boolean | null
          can_view_analytics: boolean | null
          created_at: string | null
          id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          can_create_events?: boolean | null
          can_delete_events?: boolean | null
          can_edit_events?: boolean | null
          can_manage_attendees?: boolean | null
          can_manage_email_campaigns?: boolean | null
          can_view_analytics?: boolean | null
          created_at?: string | null
          id?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          can_create_events?: boolean | null
          can_delete_events?: boolean | null
          can_edit_events?: boolean | null
          can_manage_attendees?: boolean | null
          can_manage_email_campaigns?: boolean | null
          can_view_analytics?: boolean | null
          created_at?: string | null
          id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_permissions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          avatar: string | null
          created_at: string
          email: string
          id: string
          is_invitation: boolean | null
          name: string
          organization_id: string | null
          role: string
        }
        Insert: {
          avatar?: string | null
          created_at?: string
          email: string
          id: string
          is_invitation?: boolean | null
          name: string
          organization_id?: string | null
          role: string
        }
        Update: {
          avatar?: string | null
          created_at?: string
          email?: string
          id?: string
          is_invitation?: boolean | null
          name?: string
          organization_id?: string | null
          role?: string
        }
        Relationships: [
          {
            foreignKeyName: "users_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

