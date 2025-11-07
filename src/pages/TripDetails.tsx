import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  MapPin,
  Calendar,
  Users,
  DollarSign,
  Hotel,
  Car,
  User,
  ArrowLeft,
  Clock,
  Cloud,
  Phone,
  AlertTriangle,
} from "lucide-react";

interface Trip {
  id: number;
  state: string;
  cities: string[];
  numPeople: number;
  budget: number;
  startDate: string;
  bookedAt: string;
  status: string;
  selections?: {
    hotels: Record<number, string>;
    transport: Record<number, string>;
    guides: Record<number, string>;
  };
}

interface Activity {
  time: string;
  title: string;
  description: string;
  location: string;
}

const TripDetails = () => {
  const navigate = useNavigate();
  const { id } = useParams();
  const [trip, setTrip] = useState<Trip | null>(null);

  useEffect(() => {
    const myTrips = localStorage.getItem("myTrips");
    if (myTrips) {
      const trips: Trip[] = JSON.parse(myTrips);
      const foundTrip = trips.find((t) => t.id === parseInt(id || "0"));
      if (foundTrip) {
        setTrip(foundTrip);
      } else {
        navigate("/my-trips");
      }
    } else {
      navigate("/my-trips");
    }
  }, [id, navigate]);

  if (!trip) return null;

  const mockActivitiesPerCity = [
    {
      time: "7:30 AM",
      title: "Morning Preparation",
      description: "Get ready for exploration",
      location: "Hotel",
    },
    {
      time: "9:00 AM",
      title: "Breakfast",
      description: "Local specialties",
      location: "Restaurant",
    },
    {
      time: "10:30 AM",
      title: "Visit Main Attraction",
      description: "Famous landmarks",
      location: "City Center",
    },
    {
      time: "12:30 PM",
      title: "Cultural Site",
      description: "Heritage sites",
      location: "Historical Area",
    },
    {
      time: "2:00 PM",
      title: "Lunch",
      description: "Traditional cuisine",
      location: "Local Restaurant",
    },
    {
      time: "4:00 PM",
      title: "Shopping",
      description: "Local markets",
      location: "Market Area",
    },
    {
      time: "6:30 PM",
      title: "Sunset Point",
      description: "Evening views",
      location: "Viewpoint",
    },
    {
      time: "8:30 PM",
      title: "Dinner",
      description: "Regional dishes",
      location: "Restaurant",
    },
  ];

  const mockWeatherData = [
    { temp: "28°C", condition: "Sunny", icon: "☀️" },
    { temp: "26°C", condition: "Partly Cloudy", icon: "⛅" },
    { temp: "24°C", condition: "Cloudy", icon: "☁️" },
    { temp: "27°C", condition: "Clear", icon: "🌤️" },
    { temp: "29°C", condition: "Sunny", icon: "☀️" },
  ];

  const helplineNumbers = [
    { name: "Police", number: "100", icon: "🚔" },
    { name: "Ambulance", number: "108", icon: "🚑" },
    { name: "Fire", number: "101", icon: "🚒" },
    { name: "Tourist Helpline", number: "1363", icon: "ℹ️" },
    { name: "Women Helpline", number: "1091", icon: "👮‍♀️" },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-primary/5 py-12 px-4">
      <div className="max-w-5xl mx-auto">
        <Button
          variant="ghost"
          onClick={() => navigate("/my-trips")}
          className="mb-6"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back to My Trips
        </Button>

        <Card className="p-8 mb-8 shadow-xl">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
                {trip.state} Adventure
              </h1>
              <p className="text-muted-foreground">
                Booked on{" "}
                {new Date(trip.bookedAt).toLocaleDateString("en-US", {
                  month: "long",
                  day: "numeric",
                  year: "numeric",
                })}
              </p>
            </div>
            {/* Status badge intentionally hidden in the experience/details view */}
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div className="flex items-center gap-3 p-4 bg-muted/50 rounded-lg">
                <MapPin className="w-6 h-6 text-primary" />
                <div>
                  <p className="text-sm text-muted-foreground">Destinations</p>
                  <p className="font-semibold">{trip.cities.join(", ")}</p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-4 bg-muted/50 rounded-lg">
                <Calendar className="w-6 h-6 text-secondary" />
                <div>
                  <p className="text-sm text-muted-foreground">Start Date</p>
                  <p className="font-semibold">
                    {new Date(trip.startDate).toLocaleDateString("en-US", {
                      weekday: "long",
                      month: "long",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex items-center gap-3 p-4 bg-muted/50 rounded-lg">
                <Users className="w-6 h-6 text-accent" />
                <div>
                  <p className="text-sm text-muted-foreground">Travelers</p>
                  <p className="font-semibold">
                    {trip.numPeople}{" "}
                    {trip.numPeople === 1 ? "Person" : "People"}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-3 p-4 bg-muted/50 rounded-lg">
                <DollarSign className="w-6 h-6 text-primary" />
                <div>
                  <p className="text-sm text-muted-foreground">Total Cost</p>
                  <p className="font-semibold text-xl text-primary">
                    ₹{Math.round(trip.budget * trip.numPeople * 1.18)}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </Card>

        {/* Emergency Section */}
        <Card className="p-6 mb-8 bg-destructive/10 border-destructive/20">
          <div className="flex flex-col md:flex-row gap-6 items-center justify-between">
            <div className="flex items-center gap-4">
              <AlertTriangle className="w-8 h-8 text-destructive" />
              <div>
                <h3 className="text-xl font-bold text-destructive">
                  Emergency Assistance
                </h3>
                <p className="text-sm text-muted-foreground">
                  Available 24/7 for your safety
                </p>
              </div>
            </div>
            <Button
              variant="destructive"
              size="lg"
              className="font-semibold"
              onClick={() => (window.location.href = "tel:100")}
            >
              Call Emergency
            </Button>
          </div>
        </Card>

        {/* Helpline Numbers */}
        <Card className="p-6 mb-8 shadow-lg">
          <div className="flex items-center gap-3 mb-4">
            <Phone className="w-6 h-6 text-primary" />
            <h2 className="text-2xl font-bold">Important Helpline Numbers</h2>
          </div>
          <div className="grid md:grid-cols-3 gap-4">
            {helplineNumbers.map((helpline, idx) => (
              <div
                key={idx}
                className="flex items-center gap-3 p-4 bg-muted/50 rounded-lg"
              >
                <span className="text-2xl">{helpline.icon}</span>
                <div>
                  <p className="font-semibold">{helpline.name}</p>
                  <a
                    href={`tel:${helpline.number}`}
                    className="text-primary font-bold hover:underline"
                  >
                    {helpline.number}
                  </a>
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Day by Day Itinerary */}
        <h2 className="text-3xl font-bold mb-6">Day-by-Day Itinerary</h2>
        <div className="space-y-6">
          {trip.cities.map((city, idx) => (
            <Card key={idx} className="p-6 shadow-lg">
              <div className="flex items-center gap-4 mb-4 pb-4 border-b border-border">
                <div className="flex items-center justify-center w-12 h-12 rounded-full bg-gradient-to-br from-primary to-accent text-white font-bold text-lg">
                  {idx + 1}
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold">{city}</h3>
                  <p className="text-muted-foreground">
                    {new Date(
                      new Date(trip.startDate).getTime() + idx * 86400000
                    ).toLocaleDateString("en-US", {
                      weekday: "long",
                      month: "long",
                      day: "numeric",
                    })}
                  </p>
                </div>
                <div className="flex items-center gap-3 bg-primary/10 px-4 py-2 rounded-lg">
                  <Cloud className="w-5 h-5 text-primary" />
                  <div>
                    <p className="text-2xl font-bold">
                      {mockWeatherData[idx % mockWeatherData.length].icon}
                    </p>
                    <p className="text-sm font-semibold">
                      {mockWeatherData[idx % mockWeatherData.length].temp}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {mockWeatherData[idx % mockWeatherData.length].condition}
                    </p>
                  </div>
                </div>
              </div>

              {/* Activities */}
              <div className="space-y-3 mb-4">
                {mockActivitiesPerCity.slice(0, 4).map((activity, actIdx) => (
                  <div key={actIdx} className="flex gap-3 text-sm">
                    <div className="flex items-center gap-1 text-primary font-semibold min-w-[80px]">
                      <Clock className="w-3 h-3" />
                      {activity.time}
                    </div>
                    <div>
                      <p className="font-semibold">{activity.title}</p>
                      <p className="text-muted-foreground">
                        {activity.location}
                      </p>
                    </div>
                  </div>
                ))}
              </div>

              {/* Selections */}
              {trip.selections && (
                <div className="grid md:grid-cols-3 gap-4 mt-4 pt-4 border-t border-border">
                  <div className="flex items-center gap-2">
                    <Hotel className="w-5 h-5 text-primary" />
                    <div>
                      <p className="text-xs text-muted-foreground">Hotel</p>
                      <p className="font-semibold text-sm">Selected</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Car className="w-5 h-5 text-secondary" />
                    <div>
                      <p className="text-xs text-muted-foreground">Transport</p>
                      <p className="font-semibold text-sm">Selected</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <User className="w-5 h-5 text-accent" />
                    <div>
                      <p className="text-xs text-muted-foreground">Guide</p>
                      <p className="font-semibold text-sm">Selected</p>
                    </div>
                  </div>
                </div>
              )}
            </Card>
          ))}
        </div>

        <div className="mt-8 text-center">
          <p className="text-muted-foreground mb-4">
            Need to make changes or cancel this trip?
          </p>
          <Button variant="outline">Contact Support</Button>
        </div>
      </div>
    </div>
  );
};

export default TripDetails;
