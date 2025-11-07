import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { supabase } from "@/lib/supabase";

const DevDbStatus = () => {
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  const runChecks = async () => {
    setLoading(true);
    setError(null);
    const out: any = {};
    try {
      // try counts using head=true to avoid returning rows
      const tables = [
        "hotels",
        "transport_options",
        "guides",
        "trips",
        "bookings",
      ];
      for (const t of tables) {
        try {
          const { count, error: e } = await supabase
            .from(t)
            .select("id", { count: "exact", head: true });
          if (e) {
            out[t] = { error: e.message || JSON.stringify(e) };
          } else {
            out[t] = { count };
          }
        } catch (e: any) {
          out[t] = { error: e.message || String(e) };
        }
      }

      // attempt to read specific trip columns to detect schema issues
      try {
        const { data, error: tripErr } = await supabase
          .from("trips")
          .select("id,budget_per_person,start_date,total_days")
          .limit(1);
        if (tripErr) {
          out.trips_select = {
            error: tripErr.message || JSON.stringify(tripErr),
          };
        } else {
          out.trips_select = { ok: true, sample: data };
        }
      } catch (e: any) {
        out.trips_select = { error: e.message || String(e) };
      }

      setResults(out);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    runChecks();
  }, []);

  return (
    <div className="min-h-screen p-8 bg-background">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">Dev DB Status</h1>
        <Card className="p-6 mb-4">
          <div className="flex gap-2">
            <Button onClick={runChecks} disabled={loading}>
              {loading ? "Checking..." : "Run Checks"}
            </Button>
            <div className="text-sm text-muted-foreground">
              This runs simple read checks against your Supabase tables.
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="font-semibold mb-3">Results</h2>
          {error && <div className="text-red-600">{error}</div>}
          <pre className="whitespace-pre-wrap text-sm">
            {JSON.stringify(results, null, 2)}
          </pre>
        </Card>
      </div>
    </div>
  );
};

export default DevDbStatus;
