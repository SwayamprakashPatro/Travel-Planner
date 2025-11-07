import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MapPin, Calendar, Users, CheckCircle, Plus } from "lucide-react";
import { supabase } from "@/lib/supabase";

interface Trip {
  id: number;
  state: string;
  cities: string[];
  numPeople: number;
  budget: number;
  startDate: string;
  bookedAt: string;
  status: string;
}

const MyTrips = () => {
  const navigate = useNavigate();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastResponse, setLastResponse] = useState<any>(null);
  const [showRaw, setShowRaw] = useState(false);

  useEffect(() => {
    // Load bookings from Supabase and map to UI Trip shape
    const loadBookings = async () => {
      setLoading(true);
      setError(null);
      try {
        const { data, error } = await supabase
          .from("bookings")
          // avoid using PostgREST relationship joins (trip(*)) because the REST schema
          // cache may be stale or the FK may be missing; fetch trip_id and join client-side
          .select("id,booked_at,status,total_amount,selections,trip_id")
          .order("booked_at", { ascending: false })
          .limit(100);
        if (error) throw error;
        // If the joined `trip` object isn't present (PostgREST schema cache issue),
        // fetch trips client-side for the missing trip_ids and merge them.
        const rows = (data || []) as any[];
        // save raw response for debugging in UI
        setLastResponse(rows);
        const missingTripIds = rows
          .filter((r) => !r.trip && r.trip_id)
          .map((r) => r.trip_id);
        let tripsById: Record<number, any> = {};
        if (missingTripIds.length > 0) {
          const { data: tripsData, error: tripsErr } = await supabase
            .from("trips")
            // request columns that exist in the current schema
            .select("id,title,cities,start_date,budget_per_person,total_days")
            .in("id", missingTripIds);
          if (!tripsErr && tripsData) {
            tripsById = Object.fromEntries(
              (tripsData as any[]).map((t) => [t.id, t])
            );
          }
        }

        const mapped = rows.map((b: any) => {
          const tripObj = b.trip || tripsById[b.trip_id] || null;
          // defensive: selections may be null or an object; compute numPeople
          const sel = b.selections || {};
          const selObj =
            typeof sel === "string"
              ? (() => {
                  try {
                    return JSON.parse(sel);
                  } catch {
                    return {};
                  }
                })()
              : sel;
          const travelersCount =
            selObj?.travelers?.length || selObj?.numPeople || 1;
          const numPeople = tripObj?.num_people || travelersCount || 1;
          const budgetPerPerson =
            tripObj?.budget_per_person ||
            Math.round((b.total_amount || 0) / numPeople);

          return {
            id: b.id,
            state: tripObj?.title || "Trip",
            cities: tripObj?.cities || [],
            numPeople,
            selections: selObj,
            // map budget_per_person -> budget for UI
            budget: budgetPerPerson,
            startDate: tripObj?.start_date || b.booked_at,
            bookedAt: b.booked_at,
            // prefer the DB status; if missing use 'pending' as a safe default
            status: b.status || "pending",
          };
        });
        setTrips(mapped);
        // Persist a lightweight copy for TripDetails which currently reads from localStorage
        try {
          localStorage.setItem("myTrips", JSON.stringify(mapped));
        } catch (e) {
          // ignore storage errors
        }
      } catch (e: any) {
        // eslint-disable-next-line no-console
        console.error("Failed to load bookings", e);
        setError(e?.message || String(e));
      } finally {
        setLoading(false);
      }
    };

    loadBookings();

    // Subscribe to realtime changes on bookings so UI updates automatically
    const channel = supabase
      .channel("public:bookings")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "bookings" },
        () => {
          loadBookings();
        }
      )
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "bookings" },
        () => {
          loadBookings();
        }
      )
      .subscribe();

    return () => {
      try {
        channel.unsubscribe();
      } catch (e) {
        // ignore
      }
    };
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-accent/5 py-12 px-4">
      <div className="max-w-6xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              My Trips
            </h1>
            <p className="text-muted-foreground">Manage your travel bookings</p>
          </div>
          <Button variant="hero" onClick={() => navigate("/planning")}>
            <Plus className="w-5 h-5 mr-2" />
            Plan New Trip
          </Button>
        </div>

        {error ? (
          <Card className="p-6 text-center">Error loading trips: {error}</Card>
        ) : trips.length === 0 ? (
          <Card className="p-12 text-center">
            <div className="max-w-md mx-auto space-y-4">
              <div className="w-20 h-20 bg-muted rounded-full flex items-center justify-center mx-auto mb-4">
                <MapPin className="w-10 h-10 text-muted-foreground" />
              </div>
              <h2 className="text-2xl font-bold">No Trips Yet</h2>
              <p className="text-muted-foreground">
                Start planning your dream vacation today!
              </p>
              <Button
                variant="hero"
                onClick={() => navigate("/planning")}
                className="mt-4"
              >
                Plan Your First Trip
              </Button>
              <div className="mt-4">
                <Button variant="ghost" onClick={() => setShowRaw((s) => !s)}>
                  {showRaw ? "Hide" : "Show"} raw bookings response
                </Button>
                {showRaw && (
                  <pre className="text-xs text-left p-2 mt-2 bg-muted/10 rounded max-h-60 overflow-auto">
                    {JSON.stringify(lastResponse, null, 2)}
                  </pre>
                )}
                <p className="text-xs text-muted-foreground mt-2">
                  If your bookings exist in the database but do not appear here,
                  the cause is usually:
                </p>
                <ul className="text-xs text-muted-foreground list-disc list-inside">
                  <li>
                    PostgREST schema cache needs a DB restart (run
                    `fix_schema.sql` and restart DB)
                  </li>
                  <li>
                    Row-Level Security (RLS) is blocking anonymous reads — check
                    RLS policies for `bookings`/`trips`
                  </li>
                </ul>
              </div>
            </div>
          </Card>
        ) : (
          <div className="grid md:grid-cols-2 gap-6">
            {trips.map((trip) => (
              <Card
                key={trip.id}
                className="p-6 hover:shadow-xl transition-shadow"
              >
                <div className="flex justify-between items-start mb-4">
                  <h3 className="text-2xl font-bold">{trip.state}</h3>
                  {/* Hide the prominent status pill for 'confirmed' to reduce visual noise */}
                  {trip.status &&
                    String(trip.status).toLowerCase() !== "confirmed" && (
                      <Badge
                        variant="secondary"
                        className="flex items-center gap-1"
                      >
                        <CheckCircle className="w-3 h-3" />
                        {trip.status}
                      </Badge>
                    )}
                </div>

                <div className="space-y-3 mb-4">
                  <div className="flex items-start gap-2">
                    <MapPin className="w-5 h-5 text-primary mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-sm text-muted-foreground">Cities</p>
                      <p className="font-semibold">{trip.cities.join(", ")}</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-2">
                    <Calendar className="w-5 h-5 text-secondary mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-sm text-muted-foreground">
                        Start Date
                      </p>
                      <p className="font-semibold">
                        {new Date(trip.startDate).toLocaleDateString("en-US", {
                          month: "long",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-start gap-2">
                    <Users className="w-5 h-5 text-accent mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-sm text-muted-foreground">Travelers</p>
                      <p className="font-semibold">
                        {trip.numPeople}{" "}
                        {trip.numPeople === 1 ? "Person" : "People"}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="pt-4 border-t border-border">
                  <div className="flex justify-between items-center">
                    <div>
                      <p className="text-sm text-muted-foreground">
                        Total Cost
                      </p>
                      <p className="text-xl font-bold text-primary">
                        ₹{Math.round(trip.budget * trip.numPeople * 1.18)}
                      </p>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => navigate(`/trip/${trip.id}`)}
                    >
                      View Details
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}

        <div className="mt-8 text-center">
          <Button variant="ghost" onClick={() => navigate("/")}>
            Back to Home
          </Button>
        </div>
      </div>
    </div>
  );
};

export default MyTrips;
