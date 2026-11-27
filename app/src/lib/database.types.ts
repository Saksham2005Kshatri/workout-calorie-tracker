
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "daily_summary": {
                  Row: {
                    "calorie_target": number,"calories_burned": number,"calories_in": number,"carbs_g": number,"fat_g": number,"id": string,"protein_g": number,"summary_date": string,"user_id": string,"weight_kg": number | null,"workout_count": number
                  }
                  ComputedFields: never
                  Insert: {
                    "calorie_target": number,"calories_burned": number,"calories_in": number,"carbs_g": number,"fat_g": number,"id"?: string,"protein_g": number,"summary_date": string,"user_id": string,"weight_kg"?: number | null,"workout_count": number
                  }
                  Update: {
                    "calorie_target"?: number,"calories_burned"?: number,"calories_in"?: number,"carbs_g"?: number,"fat_g"?: number,"id"?: string,"protein_g"?: number,"summary_date"?: string,"user_id"?: string,"weight_kg"?: number | null,"workout_count"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "daily_summary_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"exercise": {
                  Row: {
                    "created_by": string | null,"equipment": string | null,"id": string,"is_custom": boolean | null,"muscle_group": string,"name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_by"?: string | null,"equipment"?: string | null,"id"?: string,"is_custom"?: never,"muscle_group": string,"name": string
                  }
                  Update: {
                    "created_by"?: string | null,"equipment"?: string | null,"id"?: string,"is_custom"?: never,"muscle_group"?: string,"name"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercise_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"exercise_set": {
                  Row: {
                    "completed_at": string,"reps": number,"session_exercise_id": string,"set_no": number,"user_id": string,"weight_kg": number
                  }
                  ComputedFields: never
                  Insert: {
                    "completed_at"?: string,"reps": number,"session_exercise_id": string,"set_no": number,"user_id"?: string,"weight_kg": number
                  }
                  Update: {
                    "completed_at"?: string,"reps"?: number,"session_exercise_id"?: string,"set_no"?: number,"user_id"?: string,"weight_kg"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "exercise_set_parent_fk"
      columns: ["session_exercise_id","user_id"]
isOneToOne: false
      referencedRelation: "session_exercise"
      referencedColumns: ["id","user_id"]
    }
                  ]
                },"food_item": {
                  Row: {
                    "carbs_per_100g": number,"created_by": string | null,"fat_per_100g": number,"id": string,"kcal_per_100g": number,"name": string,"protein_per_100g": number,"source": string
                  }
                  ComputedFields: never
                  Insert: {
                    "carbs_per_100g": number,"created_by"?: string | null,"fat_per_100g": number,"id"?: string,"kcal_per_100g": number,"name": string,"protein_per_100g": number,"source": string
                  }
                  Update: {
                    "carbs_per_100g"?: number,"created_by"?: string | null,"fat_per_100g"?: number,"id"?: string,"kcal_per_100g"?: number,"name"?: string,"protein_per_100g"?: number,"source"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "food_item_created_by_fkey"
      columns: ["created_by"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"meal": {
                  Row: {
                    "eaten_at": string,"id": string,"meal_type": string,"photo_url": string | null,"status": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "eaten_at"?: string,"id"?: string,"meal_type": string,"photo_url"?: string | null,"status"?: string,"user_id"?: string
                  }
                  Update: {
                    "eaten_at"?: string,"id"?: string,"meal_type"?: string,"photo_url"?: string | null,"status"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "meal_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"meal_item": {
                  Row: {
                    "calories": number,"carbs_g": number,"fat_g": number,"food_item_id": string | null,"id": string,"ingredient_name": string,"meal_id": string,"portion_g": number,"protein_g": number,"source": string,"user_confirmed": boolean,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "calories": number,"carbs_g": number,"fat_g": number,"food_item_id"?: string | null,"id"?: string,"ingredient_name": string,"meal_id": string,"portion_g": number,"protein_g": number,"source": string,"user_confirmed"?: boolean,"user_id"?: string
                  }
                  Update: {
                    "calories"?: number,"carbs_g"?: number,"fat_g"?: number,"food_item_id"?: string | null,"id"?: string,"ingredient_name"?: string,"meal_id"?: string,"portion_g"?: number,"protein_g"?: number,"source"?: string,"user_confirmed"?: boolean,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "meal_item_food_item_id_fkey"
      columns: ["food_item_id"]
isOneToOne: false
      referencedRelation: "food_item"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "meal_item_meal_fk"
      columns: ["meal_id","user_id"]
isOneToOne: false
      referencedRelation: "meal"
      referencedColumns: ["id","user_id"]
    },{
      foreignKeyName: "meal_item_meal_fk"
      columns: ["meal_id","user_id"]
isOneToOne: false
      referencedRelation: "meal_totals"
      referencedColumns: ["meal_id","user_id"]
    }
                  ]
                },"session_exercise": {
                  Row: {
                    "exercise_id": string,"id": string,"position": number,"session_id": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "exercise_id": string,"id"?: string,"position": number,"session_id": string,"user_id"?: string
                  }
                  Update: {
                    "exercise_id"?: string,"id"?: string,"position"?: number,"session_id"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "session_exercise_exercise_id_fkey"
      columns: ["exercise_id"]
isOneToOne: false
      referencedRelation: "exercise"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "session_exercise_session_fk"
      columns: ["session_id","user_id"]
isOneToOne: false
      referencedRelation: "workout_session"
      referencedColumns: ["id","user_id"]
    }
                  ]
                },"user_profile": {
                  Row: {
                    "activity_level": string,"birth_date": string,"bmr_kcal": number,"carb_target_g": number,"daily_calorie_target": number,"fat_target_g": number,"fitness_goal": string,"gender": string,"height_cm": number,"id": string,"protein_target_g": number,"target_weight_kg": number | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "activity_level": string,"birth_date": string,"bmr_kcal": number,"carb_target_g": number,"daily_calorie_target": number,"fat_target_g": number,"fitness_goal": string,"gender": string,"height_cm": number,"id"?: string,"protein_target_g": number,"target_weight_kg"?: number | null,"updated_at"?: string
                  }
                  Update: {
                    "activity_level"?: string,"birth_date"?: string,"bmr_kcal"?: number,"carb_target_g"?: number,"daily_calorie_target"?: number,"fat_target_g"?: number,"fitness_goal"?: string,"gender"?: string,"height_cm"?: number,"id"?: string,"protein_target_g"?: number,"target_weight_kg"?: number | null,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "user_profile_id_fkey"
      columns: ["id"]
isOneToOne: true
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"users": {
                  Row: {
                    "created_at": string,"display_name": string,"id": string,"is_active": boolean,"timezone": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"display_name": string,"id": string,"is_active"?: boolean,"timezone"?: string
                  }
                  Update: {
                    "created_at"?: string,"display_name"?: string,"id"?: string,"is_active"?: boolean,"timezone"?: string
                  }
                  Relationships: [
                    
                  ]
                },"weight_log": {
                  Row: {
                    "created_at": string,"id": string,"logged_on": string,"user_id": string,"weight_kg": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"logged_on"?: string,"user_id"?: string,"weight_kg": number
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"logged_on"?: string,"user_id"?: string,"weight_kg"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "weight_log_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                },"workout_session": {
                  Row: {
                    "ended_at": string | null,"est_calories_burned": number,"id": string,"notes": string | null,"started_at": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "ended_at"?: string | null,"est_calories_burned"?: number,"id"?: string,"notes"?: string | null,"started_at"?: string,"user_id"?: string
                  }
                  Update: {
                    "ended_at"?: string | null,"est_calories_burned"?: number,"id"?: string,"notes"?: string | null,"started_at"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "workout_session_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            "meal_totals": {
                  Row: {
                    "meal_id": string,"total_calories": number | null,"total_carbs_g": number | null,"total_fat_g": number | null,"total_protein_g": number | null,"user_id": string
                  }
                  ComputedFields: never
                  Relationships: [
                    {
      foreignKeyName: "meal_user_id_fkey"
      columns: ["user_id"]
isOneToOne: false
      referencedRelation: "users"
      referencedColumns: ["id"]
    }
                  ]
                }
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

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            
          }
        }
} as const
