import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Star, Hotel, Car, User, Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { supabase } from "@/lib/supabase";

interface TripData {
  cities: string[];
}

interface Hotel {
  id: number | string;
  name: string;
  rating: number;
  price: number;
  image: string;
}

interface Transport {
  id: string;
  type: string;
  name: string;
  price: number;
}

interface Guide {
  id: string;
  name: string;
  rating: number;
  price: number;
  languages: string[];
}

const Selection = () => {
  const navigate = useNavigate();
  const [tripData, setTripData] = useState<TripData | null>(null);
  const [selectedDay, setSelectedDay] = useState(0);
  const [selections, setSelections] = useState<{
    hotels: Record<number, string>;
    transport: Record<number, string>;
    guides: Record<number, string>;
  }>({ hotels: {}, transport: {}, guides: {} });

  const [hotels, setHotels] = useState<Hotel[]>([]);
  const [transportOptions, setTransportOptions] = useState<any[]>([]);
  const [guides, setGuides] = useState<any[]>([]);
  const [loadingCatalog, setLoadingCatalog] = useState(false);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [debugLog, setDebugLog] = useState<string[]>([]);

  useEffect(() => {
    const data = localStorage.getItem("currentTrip");
    if (!data) {
      navigate("/planning");
      return;
    }
    setTripData(JSON.parse(data));
  }, [navigate]);

  useEffect(() => {
    fetchCatalog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchCatalog = async () => {
    setLoadingCatalog(true);
    setCatalogError(null);
    setDebugLog((d) => [
      ...d,
      `fetchCatalog start ${new Date().toISOString()}`,
    ]);
    try {
      // Select only columns that exist in the current schema to avoid PostgREST
      // schema-cache errors or 400s when requesting relationships/columns that
      // don't exist (e.g. image_url, city, languages). Keep this simple and
      // fetch related data client-side if needed.
      const hRes = await supabase
        .from("hotels")
        .select("id,name,rating,price_per_night")
        .order("rating", { ascending: false })
        .limit(50);
      // Log full response for debugging schema/cache/permission issues
      // eslint-disable-next-line no-console
      console.log("hotels response:", hRes);
      setDebugLog((d) => [...d, `hotels response: ${JSON.stringify(hRes)}`]);
      const h = hRes.data;
      const he = hRes.error;
      if (he) throw he;
      setHotels(
        (h || []).map((item: any) => ({
          id: item.id,
          name: item.name,
          rating: Number(item.rating) || 0,
          price: item.price_per_night || 0,
          // image_url is stored in `hotel_images` table; if you want to surface
          // images, fetch them separately by hotel id. For now use a fallback.
          image: "🏨",
        }))
      );

      const { data: t, error: te } = await supabase
        .from("transport_options")
        .select("id,type,name,price_per_day,features")
        .limit(50);
      if (te) throw te;
      // eslint-disable-next-line no-console
      console.log("transport_options:", t);
      // normalize features/price shape for the UI
      setTransportOptions(
        (t || []).map((tr: any) => ({
          ...tr,
          // prefer price_per_day; features may contain capacity/other metadata
          price: tr.price_per_day ?? tr.features?.price ?? 0,
        }))
      );

      const gRes = await supabase
        .from("guides")
        // guide languages are stored in `guide_languages`; avoid requesting a
        // non-existent 'languages' column here to keep the query simple.
        .select("id,name,rating,price_per_day")
        .limit(50);
      // eslint-disable-next-line no-console
      console.log("guides response:", gRes);
      setDebugLog((d) => [...d, `guides response: ${JSON.stringify(gRes)}`]);
      const g = gRes.data;
      const ge = gRes.error;
      if (ge) throw ge;
      setGuides(
        (g || []).map((gd: any) => ({
          ...gd,
          // UI expects language list; fetch separately if you want actual
          // languages. For now default to empty array to avoid crashes.
          languages: [],
        }))
      );
    } catch (e: any) {
      // eslint-disable-next-line no-console
      console.error("Failed to load catalog", e);
      setCatalogError(e?.message || String(e));
      setDebugLog((d) => [...d, `fetchCatalog error: ${String(e)}`]);
    } finally {
      setLoadingCatalog(false);
    }
  };

  // Use catalog loaded from DB (falls back to empty arrays)

  const handleSelection = (
    category: "hotels" | "transport" | "guides",
    id: number | string
  ) => {
    const idStr = String(id);
    setSelections((prev) => ({
      ...prev,
      [category]: { ...prev[category], [selectedDay]: idStr },
    }));
  };

  const canProceed = () => {
    if (!tripData) return false;
    const totalDays = tripData.cities.length;
    for (let i = 0; i < totalDays; i++) {
      if (
        !selections.hotels[i] ||
        !selections.transport[i] ||
        !selections.guides[i]
      ) {
        return false;
      }
    }
    return true;
  };

  const handleContinue = () => {
    localStorage.setItem("tripSelections", JSON.stringify(selections));
    navigate("/payment");
  };

  if (!tripData) return null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-secondary/5 py-12 px-4">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-secondary to-primary bg-clip-text text-transparent">
            Customize Your Experience
          </h1>
          <p className="text-muted-foreground">
            Select hotels, transport, and guides for each day
          </p>
        </div>

        {/* Day Selector */}
        <div className="flex gap-2 mb-8 overflow-x-auto pb-2">
          {tripData.cities.map((city, idx) => (
            <button
              key={idx}
              onClick={() => setSelectedDay(idx)}
              className={cn(
                "px-6 py-3 rounded-lg font-semibold whitespace-nowrap transition-all",
                selectedDay === idx
                  ? "bg-gradient-to-r from-primary to-accent text-white shadow-lg"
                  : "bg-card hover:bg-muted"
              )}
            >
              Day {idx + 1} - {city}
              {selections.hotels[idx] &&
                selections.transport[idx] &&
                selections.guides[idx] && (
                  <Check className="inline-block w-4 h-4 ml-2" />
                )}
            </button>
          ))}
        </div>

        <div className="space-y-8">
          {/* Hotels */}
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-2">
              <Hotel className="w-6 h-6 text-primary" />
              Choose Hotel
            </h2>
            <div className="grid md:grid-cols-3 gap-4">
              {catalogError && (
                <div className="col-span-3 p-4 mb-2 text-center text-red-600 bg-red-50 rounded">
                  Failed to load catalog: {catalogError}
                </div>
              )}
              {hotels.length === 0 && !loadingCatalog && (
                <div className="col-span-3 p-6 text-center text-muted-foreground">
                  No hotels found. Make sure your Supabase schema/seed are
                  applied and `VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY` are
                  set.
                  <div className="mt-3">
                    <Button size="sm" variant="outline" onClick={fetchCatalog}>
                      Retry
                    </Button>
                  </div>
                </div>
              )}

              {hotels.map((hotel) => (
                <Card
                  key={hotel.id}
                  className={cn(
                    "p-4 cursor-pointer transition-all hover:shadow-lg",
                    selections.hotels[selectedDay] === String(hotel.id)
                      ? "border-2 border-primary shadow-lg"
                      : "hover:border-primary/50"
                  )}
                  onClick={() => handleSelection("hotels", hotel.id)}
                >
                  <div className="text-4xl mb-2">{hotel.image}</div>
                  <h3 className="font-semibold mb-2">{hotel.name}</h3>
                  <div className="flex items-center gap-1 mb-2">
                    <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                    <span className="text-sm">{hotel.rating}</span>
                  </div>
                  <p className="text-lg font-bold text-primary">
                    ₹{hotel.price}/night
                  </p>
                </Card>
              ))}
            </div>
          </div>

          {/* Debug output suppressed in UI by default. Use browser console for logs. */}

          {/* Transport */}
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-2">
              <Car className="w-6 h-6 text-secondary" />
              Choose Transport
            </h2>
            <div className="grid md:grid-cols-3 gap-4">
              {transportOptions.length === 0 && !loadingCatalog && (
                <div className="col-span-3 p-6 text-center text-muted-foreground">
                  No transport options found.{" "}
                  <Button size="sm" variant="outline" onClick={fetchCatalog}>
                    Retry
                  </Button>
                </div>
              )}

              {transportOptions.map((transport) => (
                <Card
                  key={transport.id}
                  className={cn(
                    "p-4 cursor-pointer transition-all hover:shadow-lg",
                    selections.transport[selectedDay] === String(transport.id)
                      ? "border-2 border-secondary shadow-lg"
                      : "hover:border-secondary/50"
                  )}
                  onClick={() => handleSelection("transport", transport.id)}
                >
                  <Badge variant="secondary" className="mb-2">
                    {transport.type}
                  </Badge>
                  <h3 className="font-semibold mb-2">{transport.name}</h3>
                  <p className="text-lg font-bold text-secondary">
                    ₹{transport.price_per_day ?? transport.price}/day
                  </p>
                </Card>
              ))}
            </div>
          </div>

          {/* Guides */}
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-2">
              <User className="w-6 h-6 text-accent" />
              Choose Guide
            </h2>
            <div className="grid md:grid-cols-3 gap-4">
              {guides.length === 0 && !loadingCatalog && (
                <div className="col-span-3 p-6 text-center text-muted-foreground">
                  No guides found.{" "}
                  <Button size="sm" variant="outline" onClick={fetchCatalog}>
                    Retry
                  </Button>
                </div>
              )}

              {guides.map((guide) => (
                <Card
                  key={guide.id}
                  className={cn(
                    "p-4 cursor-pointer transition-all hover:shadow-lg",
                    selections.guides[selectedDay] === String(guide.id)
                      ? "border-2 border-accent shadow-lg"
                      : "hover:border-accent/50"
                  )}
                  onClick={() => handleSelection("guides", guide.id)}
                >
                  <h3 className="font-semibold mb-2">{guide.name}</h3>
                  {guide.rating > 0 && (
                    <>
                      <div className="flex items-center gap-1 mb-2">
                        <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                        <span className="text-sm">{guide.rating}</span>
                      </div>
                      <div className="flex flex-wrap gap-1 mb-2">
                        {(guide.languages || []).map((lang: string) => (
                          <Badge
                            key={lang}
                            variant="outline"
                            className="text-xs"
                          >
                            {lang}
                          </Badge>
                        ))}
                      </div>
                    </>
                  )}
                  <p className="text-lg font-bold text-accent">
                    {guide.price_per_day > 0
                      ? `₹${guide.price_per_day}/day`
                      : guide.price > 0
                      ? `₹${guide.price}/day`
                      : "Free"}
                  </p>
                </Card>
              ))}
            </div>
          </div>
        </div>

        <div className="flex gap-4 mt-8">
          <Button
            variant="outline"
            onClick={() => navigate("/itinerary")}
            className="flex-1 h-12 text-lg"
          >
            Back to Itinerary
          </Button>
          <Button
            variant="sunset"
            onClick={handleContinue}
            disabled={!canProceed()}
            className="flex-1 h-12 text-lg"
          >
            Continue to Payment
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Selection;
