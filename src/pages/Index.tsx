import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { MapPin, Calendar, DollarSign, Star, Plane, Users } from "lucide-react";
import heroImage from "@/assets/hero-travel.jpg";
import { supabase } from "@/lib/supabase";

const Index = () => {
  const navigate = useNavigate();

  async function insertTestTrip() {
    try {
      const { data: inserted, error: insertError } = await supabase
        .from("trips")
        .insert({
          title: "UI Test Trip",
          user_id: null,
        })
        .select();
      // eslint-disable-next-line no-console
      console.log("insert result", inserted, insertError);

      const { data, error } = await supabase
        .from("trips")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(10);
      // eslint-disable-next-line no-console
      console.log("trips after insert", data, error);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("Insert test trip failed", e);
    }
  }

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <img
          src={heroImage}
          alt="Travel destination"
          className="absolute inset-0 w-full h-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-br from-primary/80 via-accent/80 to-secondary/80" />

        <div className="relative z-10 text-center text-white px-4 max-w-5xl mx-auto">
          <h1 className="text-5xl md:text-7xl font-bold mb-6 animate-fade-in">
            Your Journey Starts Here
          </h1>
          <p className="text-xl md:text-2xl mb-8 text-white/90">
            Plan your dream vacation with personalized itineraries, hotels, and
            guides
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Button
              variant="hero"
              size="lg"
              onClick={() => navigate("/planning")}
              className="text-lg px-8 h-14 min-w-[200px]"
            >
              <Plane className="mr-2 w-5 h-5" />
              Start Planning
            </Button>
            <Button
              variant="outline"
              size="lg"
              onClick={() => navigate("/explore")}
              className="text-lg px-8 h-14 min-w-[200px] bg-white/10 backdrop-blur-sm text-white border-white/30 hover:bg-white/20"
            >
              <MapPin className="mr-2 w-5 h-5" />
              Explore
            </Button>
            <Button
              variant="outline"
              size="lg"
              onClick={() => navigate("/auth")}
              className="text-lg px-8 h-14 min-w-[200px] bg-white/10 backdrop-blur-sm text-white border-white/30 hover:bg-white/20"
            >
              Sign In
            </Button>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 px-4 bg-background">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold mb-4 bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Why Choose Us?
            </h2>
            <p className="text-xl text-muted-foreground">
              Everything you need for the perfect trip
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <Card className="p-8 text-center hover:shadow-2xl transition-all hover:-translate-y-2">
              <div className="w-16 h-16 bg-gradient-to-br from-primary to-accent rounded-full flex items-center justify-center mx-auto mb-4">
                <MapPin className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold mb-3">Custom Itineraries</h3>
              <p className="text-muted-foreground">
                Personalized day-by-day plans tailored to your preferences and
                budget
              </p>
            </Card>

            <Card className="p-8 text-center hover:shadow-2xl transition-all hover:-translate-y-2">
              <div className="w-16 h-16 bg-gradient-to-br from-secondary to-[hsl(25,95%,60%)] rounded-full flex items-center justify-center mx-auto mb-4">
                <Calendar className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold mb-3">Flexible Planning</h3>
              <p className="text-muted-foreground">
                Choose your dates, destinations, and activities with complete
                freedom
              </p>
            </Card>

            <Card className="p-8 text-center hover:shadow-2xl transition-all hover:-translate-y-2">
              <div className="w-16 h-16 bg-gradient-to-br from-accent to-primary rounded-full flex items-center justify-center mx-auto mb-4">
                <DollarSign className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold mb-3">Budget Friendly</h3>
              <p className="text-muted-foreground">
                Options for every budget with transparent pricing and no hidden
                fees
              </p>
            </Card>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-20 px-4 bg-gradient-to-br from-muted/30 to-accent/5">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold mb-4">How It Works</h2>
            <p className="text-xl text-muted-foreground">
              Simple steps to your perfect trip
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-8">
            {[
              {
                icon: MapPin,
                title: "Choose Destination",
                desc: "Select state and cities",
              },
              { icon: Users, title: "Add Details", desc: "People and budget" },
              {
                icon: Calendar,
                title: "Pick Dates",
                desc: "Select travel dates",
              },
              { icon: Star, title: "Book & Go", desc: "Confirm and travel" },
            ].map((step, idx) => (
              <div key={idx} className="text-center">
                <div className="relative mb-6">
                  <div className="w-20 h-20 bg-gradient-to-br from-primary to-accent rounded-full flex items-center justify-center mx-auto shadow-xl">
                    <step.icon className="w-10 h-10 text-white" />
                  </div>
                  <div className="absolute -top-2 -right-2 w-8 h-8 bg-secondary text-white rounded-full flex items-center justify-center font-bold shadow-lg">
                    {idx + 1}
                  </div>
                </div>
                <h3 className="text-xl font-bold mb-2">{step.title}</h3>
                <p className="text-muted-foreground">{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 bg-gradient-to-r from-primary via-accent to-secondary">
        <div className="max-w-4xl mx-auto text-center text-white">
          <h2 className="text-4xl font-bold mb-6">Ready to Explore?</h2>
          <p className="text-xl mb-8 text-white/90">
            Join thousands of travelers who have planned their perfect trips
            with us
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button
              size="lg"
              onClick={() => navigate("/planning")}
              className="bg-white text-primary hover:bg-white/90 text-lg px-8 h-14 shadow-xl"
            >
              Start Planning Now
            </Button>
            <Button
              size="lg"
              variant="outline"
              onClick={() => navigate("/explore")}
              className="text-lg px-8 h-14 bg-white/10 backdrop-blur-sm text-white border-white/30 hover:bg-white/20"
            >
              Explore Destinations
            </Button>
            <Button
              size="lg"
              variant="outline"
              onClick={() => navigate("/my-trips")}
              className="text-lg px-8 h-14 bg-white/10 backdrop-blur-sm text-white border-white/30 hover:bg-white/20"
            >
              View My Trips
            </Button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-card py-8 px-4 border-t border-border">
        <div className="max-w-7xl mx-auto text-center text-muted-foreground">
          <div className="flex flex-col items-center gap-2">
            {/* Insert test trip removed — bookings are created via Payment flow now */}
            <p>&copy; 2025 TravelPlanner. Your journey, our passion.</p>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default Index;
