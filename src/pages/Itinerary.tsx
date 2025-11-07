import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Clock, MapPin, Info, Calendar } from "lucide-react";

interface TripData {
  state: string;
  cities: string[];
  numPeople: number;
  budget: number;
  startDate: string;
}

interface Activity {
  time: string;
  title: string;
  description: string;
  location: string;
}

interface DayItinerary {
  day: number;
  date: string;
  city: string;
  activities: Activity[];
}

const Itinerary = () => {
  const navigate = useNavigate();
  const [tripData, setTripData] = useState<TripData | null>(null);
  const [itinerary, setItinerary] = useState<DayItinerary[]>([]);

  useEffect(() => {
    const data = localStorage.getItem('currentTrip');
    if (!data) {
      navigate('/planning');
      return;
    }

    const trip: TripData = JSON.parse(data);
    setTripData(trip);

    // Generate detailed itinerary with real places
    const cityActivities: Record<string, Activity[]> = {
      "Pune": [
        { time: "7:00 AM", title: "Wake Up & Freshen Up", description: "Get ready for an exciting day of exploration", location: "Your Hotel" },
        { time: "8:30 AM", title: "Breakfast", description: "Traditional Maharashtrian breakfast with Misal Pav and Poha", location: "Vaishali Restaurant, FC Road" },
        { time: "10:30 AM", title: "Visit Shaniwar Wada", description: "Explore the historic 18th-century fortification and palace ruins", location: "Shaniwar Wada Fort" },
        { time: "12:30 PM", title: "Explore Dagdusheth Halwai Ganpati Temple", description: "Visit the famous 200-year-old temple", location: "Budhwar Peth" },
        { time: "2:00 PM", title: "Lunch", description: "Authentic Maharashtrian thali with local specialties", location: "Durvankur Restaurant, FC Road" },
        { time: "4:00 PM", title: "Shopping at Laxmi Road", description: "Browse traditional jewelry, clothes and handicrafts", location: "Laxmi Road Market" },
        { time: "6:30 PM", title: "Sunset at Parvati Hill", description: "Climb 108 steps for panoramic city views", location: "Parvati Hill Temple" },
        { time: "8:30 PM", title: "Dinner", description: "Modern Indian fusion cuisine", location: "Malaka Spice, Koregaon Park" }
      ],
      "Mumbai": [
        { time: "6:30 AM", title: "Early Morning Prep", description: "Get ready to beat the Mumbai traffic", location: "Your Hotel" },
        { time: "8:00 AM", title: "Breakfast by the Sea", description: "Mumbai-style cutting chai and bun maska", location: "Kyani & Co, Marine Lines" },
        { time: "9:30 AM", title: "Gateway of India", description: "Iconic 26-meter arch monument overlooking the Arabian Sea", location: "Apollo Bunder, Colaba" },
        { time: "11:00 AM", title: "Taj Mahal Palace Tour", description: "Admire the stunning architecture of this historic hotel", location: "Taj Mahal Palace, Colaba" },
        { time: "1:00 PM", title: "Lunch", description: "Famous butter chicken and naan", location: "Bademiya, Colaba Causeway" },
        { time: "3:00 PM", title: "Marine Drive Walk", description: "Stroll along the iconic Queen's Necklace promenade", location: "Marine Drive" },
        { time: "5:30 PM", title: "Chowpatty Beach", description: "Enjoy street food like pav bhaji and bhel puri", location: "Girgaum Chowpatty" },
        { time: "7:30 PM", title: "Crawford Market Shopping", description: "Explore the vibrant colonial-era market", location: "Crawford Market" },
        { time: "9:00 PM", title: "Dinner", description: "Coastal seafood specialties", location: "Trishna, Kala Ghoda" }
      ],
      "Jaipur": [
        { time: "7:30 AM", title: "Morning Preparation", description: "Start early to explore the Pink City", location: "Your Hotel" },
        { time: "9:00 AM", title: "Visit Amber Fort", description: "Majestic hilltop fort with stunning architecture and elephant rides", location: "Amber Fort, Devisinghpura" },
        { time: "12:00 PM", title: "City Palace Complex", description: "Royal residence with museums and courtyards", location: "City Palace, Gangori Bazaar" },
        { time: "2:00 PM", title: "Traditional Rajasthani Lunch", description: "Dal baati churma and gatte ki sabzi thali", location: "Laxmi Misthan Bhandar (LMB), Johari Bazaar" },
        { time: "4:00 PM", title: "Hawa Mahal Photo Stop", description: "Iconic Palace of Winds with 953 windows", location: "Hawa Mahal, Badi Choupad" },
        { time: "5:30 PM", title: "Jantar Mantar", description: "UNESCO World Heritage astronomical observatory", location: "Jantar Mantar, Gangori Bazaar" },
        { time: "7:00 PM", title: "Johari Bazaar Shopping", description: "Shop for jewelry, textiles and handicrafts", location: "Johari Bazaar" },
        { time: "9:00 PM", title: "Rooftop Dinner", description: "Traditional Rajasthani cuisine with folk performances", location: "Chokhi Dhani Village Resort" }
      ],
      "Goa": [
        { time: "8:00 AM", title: "Leisurely Wake Up", description: "Enjoy the beach vacation vibe", location: "Your Beach Resort" },
        { time: "9:30 AM", title: "Beach Breakfast", description: "Fresh fruit platter, pancakes and smoothies by the sea", location: "Infantaria Café, Calangute" },
        { time: "11:00 AM", title: "Water Sports at Baga Beach", description: "Parasailing, jet skiing and banana boat rides", location: "Baga Beach" },
        { time: "1:30 PM", title: "Seafood Lunch", description: "Grilled fish, prawns and crab curry", location: "Britto's, Baga Beach" },
        { time: "3:30 PM", title: "Fort Aguada Visit", description: "17th-century Portuguese fort with lighthouse", location: "Fort Aguada, Candolim" },
        { time: "5:30 PM", title: "Sunset Cruise", description: "River cruise on Mandovi with music and views", location: "Mandovi River, Panaji" },
        { time: "8:00 PM", title: "Night Market", description: "Browse handicrafts, jewelry and souvenirs", location: "Saturday Night Market, Arpora" },
        { time: "9:30 PM", title: "Dinner & Live Music", description: "Goan fish curry and bebinca dessert", location: "Thalassa, Vagator" }
      ],
      "Kochi": [
        { time: "7:00 AM", title: "Morning Routine", description: "Prepare for Kerala backwaters exploration", location: "Your Hotel" },
        { time: "8:30 AM", title: "Traditional Kerala Breakfast", description: "Appam with stew and banana", location: "Dhe Puttu, Fort Kochi" },
        { time: "10:00 AM", title: "Chinese Fishing Nets", description: "See the iconic cantilever fishing nets in action", location: "Fort Kochi Beach" },
        { time: "11:30 AM", title: "Mattancherry Palace", description: "Dutch Palace with Kerala murals", location: "Mattancherry" },
        { time: "1:00 PM", title: "Lunch on Banana Leaf", description: "Kerala sadya with 20+ dishes", location: "Kayees Rahmathullah Hotel" },
        { time: "3:00 PM", title: "Jew Town & Synagogue", description: "Explore spice markets and historic synagogue", location: "Jew Town, Mattancherry" },
        { time: "5:30 PM", title: "Kathakali Dance Show", description: "Traditional Kerala dance performance", location: "Kerala Kathakali Centre" },
        { time: "7:30 PM", title: "Backwaters Sunset Walk", description: "Peaceful evening by the canals", location: "Marine Drive" },
        { time: "9:00 PM", title: "Seafood Dinner", description: "Fresh catch prepared Kerala style", location: "Oceanos Restaurant, Fort Kochi" }
      ],
      "Udaipur": [
        { time: "7:30 AM", title: "Rise & Shine", description: "Wake up in the City of Lakes", location: "Your Hotel" },
        { time: "9:00 AM", title: "Breakfast with Lake View", description: "Continental breakfast overlooking Pichola Lake", location: "Ambrai Restaurant, Hanuman Ghat" },
        { time: "10:30 AM", title: "City Palace Tour", description: "Magnificent palace complex with museums and courtyards", location: "City Palace, Pichola" },
        { time: "1:00 PM", title: "Boat Ride on Lake Pichola", description: "Scenic boat tour to Jag Mandir island palace", location: "Lake Pichola" },
        { time: "2:30 PM", title: "Lunch", description: "Royal Rajasthani thali in heritage setting", location: "Ambrai Restaurant" },
        { time: "4:30 PM", title: "Saheliyon Ki Bari", description: "Garden of Maidens with fountains and lotus pools", location: "Saheliyon Ki Bari" },
        { time: "6:30 PM", title: "Sunset at Sajjangarh Palace", description: "Monsoon Palace with panoramic sunset views", location: "Sajjangarh Palace" },
        { time: "8:30 PM", title: "Dinner with Cultural Show", description: "Rajasthani cuisine with puppet show", location: "Bagore Ki Haveli" }
      ],
      "Bangalore": [
        { time: "8:00 AM", title: "Morning Start", description: "Begin your Silicon Valley of India tour", location: "Your Hotel" },
        { time: "9:30 AM", title: "South Indian Breakfast", description: "Masala dosa, idli and filter coffee", location: "Vidyarthi Bhavan, Basavanagudi" },
        { time: "11:00 AM", title: "Bangalore Palace", description: "Tudor-style palace with beautiful gardens", location: "Bangalore Palace, Vasanth Nagar" },
        { time: "1:00 PM", title: "Lalbagh Botanical Gardens", description: "250-acre garden with glasshouse and rare plants", location: "Lalbagh" },
        { time: "2:30 PM", title: "Lunch", description: "Traditional Karnataka meals", location: "MTR Restaurant, Lalbagh Road" },
        { time: "4:30 PM", title: "Vidhana Soudha Photo Stop", description: "Impressive legislative building", location: "Vidhana Soudha" },
        { time: "5:30 PM", title: "Shopping at Commercial Street", description: "Browse textiles, jewelry and handicrafts", location: "Commercial Street" },
        { time: "7:30 PM", title: "Evening at UB City", description: "Luxury shopping and dining complex", location: "UB City Mall" },
        { time: "9:00 PM", title: "Rooftop Dinner", description: "Multi-cuisine with city views", location: "High Ultra Lounge, Church Street" }
      ]
    };

    const getDefaultActivities = (city: string): Activity[] => [
      { time: "7:30 AM", title: "Morning Preparation", description: "Get ready for a day of exploration", location: "Your Hotel" },
      { time: "9:00 AM", title: "Breakfast", description: "Local breakfast specialties", location: `Popular Restaurant in ${city}` },
      { time: "10:30 AM", title: "Visit Main Attraction", description: "Explore the famous landmarks", location: `${city} City Center` },
      { time: "12:30 PM", title: "Cultural Site Visit", description: "Discover local heritage and history", location: `${city} Heritage Sites` },
      { time: "2:00 PM", title: "Lunch", description: "Traditional regional cuisine", location: `Local Restaurant in ${city}` },
      { time: "4:00 PM", title: "Shopping & Markets", description: "Browse local handicrafts and souvenirs", location: `${city} Market Area` },
      { time: "6:30 PM", title: "Sunset Point", description: "Enjoy scenic evening views", location: `${city} Viewpoint` },
      { time: "8:30 PM", title: "Dinner", description: "Authentic local cuisine", location: `Recommended Restaurant in ${city}` }
    ];

    const mockItinerary: DayItinerary[] = trip.cities.map((city, idx) => ({
      day: idx + 1,
      date: new Date(new Date(trip.startDate).getTime() + idx * 86400000).toLocaleDateString('en-US', { 
        weekday: 'long', 
        month: 'long', 
        day: 'numeric' 
      }),
      city,
      activities: cityActivities[city] || getDefaultActivities(city)
    }));

    setItinerary(mockItinerary);
  }, [navigate]);

  if (!tripData) return null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-primary/5 py-12 px-4">
      <div className="max-w-5xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
            Your {tripData.cities.length}-Day Itinerary
          </h1>
          <p className="text-lg text-muted-foreground">
            {tripData.state} • {tripData.numPeople} {tripData.numPeople === 1 ? 'Person' : 'People'} • ₹{tripData.budget}/person
          </p>
        </div>

        <div className="space-y-8 mb-8">
          {itinerary.map((day) => (
            <Card key={day.day} className="p-6 shadow-xl hover:shadow-2xl transition-shadow">
              <div className="flex items-center gap-4 mb-6 pb-4 border-b border-border">
                <div className="flex items-center justify-center w-16 h-16 rounded-full bg-gradient-to-br from-primary to-accent text-white font-bold text-xl">
                  {day.day}
                </div>
                <div>
                  <h2 className="text-2xl font-bold">{day.city}</h2>
                  <p className="text-muted-foreground flex items-center gap-2">
                    <Calendar className="w-4 h-4" />
                    {day.date}
                  </p>
                </div>
              </div>

              <div className="space-y-4">
                {day.activities.map((activity, idx) => (
                  <div key={idx} className="flex gap-4 p-4 rounded-lg hover:bg-muted/50 transition-colors">
                    <div className="flex items-center gap-2 text-primary font-semibold min-w-[100px]">
                      <Clock className="w-4 h-4" />
                      {activity.time}
                    </div>
                    <div className="flex-1">
                      <h3 className="font-semibold text-lg mb-1">{activity.title}</h3>
                      <p className="text-muted-foreground mb-2">{activity.description}</p>
                      <p className="text-sm text-accent flex items-center gap-1">
                        <MapPin className="w-3 h-3" />
                        {activity.location}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          ))}
        </div>

        <Card className="p-6 bg-accent/10 border-accent/20 mb-8">
          <div className="flex items-start gap-3">
            <Info className="w-5 h-5 text-accent flex-shrink-0 mt-1" />
            <div>
              <h3 className="font-semibold mb-2">Budget Estimate</h3>
              <p className="text-muted-foreground">
                Total: ₹{tripData.budget * tripData.numPeople} for {tripData.numPeople} {tripData.numPeople === 1 ? 'person' : 'people'}
                <br />
                Includes accommodation, meals, and basic activities. Excludes shopping and optional tours.
              </p>
            </div>
          </div>
        </Card>

        <div className="flex gap-4">
          <Button
            variant="outline"
            onClick={() => navigate('/planning')}
            className="flex-1 h-12 text-lg"
          >
            Modify Plan
          </Button>
          <Button
            variant="hero"
            onClick={() => navigate('/selection')}
            className="flex-1 h-12 text-lg"
          >
            Choose Hotels & Transport
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Itinerary;
