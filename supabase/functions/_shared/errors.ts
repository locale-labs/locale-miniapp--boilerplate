import { PostgrestError } from "@supabase/supabase-js";

export const isNotFoundError = (error: PostgrestError | null) =>
  !error
    ? false
    : error.code === "PGRST116" ||
      error?.details?.includes("The result contains 0 rows");
