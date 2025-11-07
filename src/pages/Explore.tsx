import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MapPin, ArrowRight, Mountain, Building, Waves, TreePine } from "lucide-react";
import { cn } from "@/lib/utils";

interface Attraction {
  name: string;
  type: string;
  description: string;
}

interface StateInfo {
  name: string;
  tagline: string;
  icon: typeof Mountain;
  cities: string[];
  attractions: Attraction[];
  bestTime: string;
  famousFor: string[];
}

const STATES_DATA: StateInfo[] = [
  {
    name: "Goa",
    tagline: "Sun, Sand & Sea",
    icon: Waves,
    cities: ["Panaji", "Calangute", "Baga", "Anjuna"],
    attractions: [
      { name: "Baga Beach", type: "Beach", description: "Popular beach with water sports and nightlife" },
      { name: "Fort Aguada", type: "Historical", description: "17th-century Portuguese fort with lighthouse" },
      { name: "Dudhsagar Falls", type: "Nature", description: "Majestic four-tiered waterfall" },
      { name: "Basilica of Bom Jesus", type: "Religious", description: "UNESCO World Heritage church" }
    ],
    bestTime: "November to February",
    famousFor: ["Beaches", "Portuguese Heritage", "Nightlife", "Seafood"]
  },
  {
    name: "Rajasthan",
    tagline: "Land of Kings",
    icon: Building,
    cities: ["Jaipur", "Udaipur", "Jodhpur", "Jaisalmer"],
    attractions: [
      { name: "Amber Fort", type: "Historical", description: "Majestic hilltop fort with stunning architecture" },
      { name: "City Palace Udaipur", type: "Palace", description: "Royal residence overlooking Lake Pichola" },
      { name: "Mehrangarh Fort", type: "Historical", description: "Imposing fort in Jodhpur with museum" },
      { name: "Thar Desert Safari", type: "Adventure", description: "Camel safari in golden sand dunes" }
    ],
    bestTime: "October to March",
    famousFor: ["Palaces", "Forts", "Desert Safari", "Royal Heritage"]
  },
  {
    name: "Kerala",
    tagline: "God's Own Country",
    icon: TreePine,
    cities: ["Kochi", "Munnar", "Alleppey", "Kovalam"],
    attractions: [
      { name: "Backwaters", type: "Nature", description: "Serene houseboat cruises through canals" },
      { name: "Munnar Tea Gardens", type: "Nature", description: "Rolling hills covered with tea plantations" },
      { name: "Periyar Wildlife", type: "Wildlife", description: "Tiger reserve and elephant sightings" },
      { name: "Kovalam Beach", type: "Beach", description: "Crescent-shaped beach with lighthouse" }
    ],
    bestTime: "September to March",
    famousFor: ["Backwaters", "Ayurveda", "Tea Gardens", "Wildlife"]
  },
  {
    name: "Maharashtra",
    tagline: "Gateway of India",
    icon: Building,
    cities: ["Mumbai", "Pune", "Lonavala", "Mahabaleshwar"],
    attractions: [
      { name: "Gateway of India", type: "Historical", description: "Iconic 26-meter arch monument" },
      { name: "Ajanta Caves", type: "Historical", description: "UNESCO World Heritage rock-cut caves" },
      { name: "Shaniwar Wada", type: "Historical", description: "18th-century fort palace in Pune" },
      { name: "Lonavala Hills", type: "Nature", description: "Hill station with waterfalls and valleys" }
    ],
    bestTime: "October to February",
    famousFor: ["Historical Sites", "Hill Stations", "Beaches", "Street Food"]
  },
  {
    name: "Karnataka",
    tagline: "Silicon Valley of India",
    icon: Building,
    cities: ["Bangalore", "Mysore", "Coorg", "Hampi"],
    attractions: [
      { name: "Mysore Palace", type: "Palace", description: "Indo-Saracenic palace with intricate interiors" },
      { name: "Hampi Ruins", type: "Historical", description: "UNESCO site with ancient temple ruins" },
      { name: "Coorg Coffee Estates", type: "Nature", description: "Lush coffee plantations in Western Ghats" },
      { name: "Bangalore Palace", type: "Palace", description: "Tudor-style architecture with beautiful gardens" }
    ],
    bestTime: "October to February",
    famousFor: ["IT Hub", "Palaces", "Coffee", "Temples"]
  },
  {
    name: "Uttarakhand",
    tagline: "Land of Gods",
    icon: Mountain,
    cities: ["Nainital", "Mussoorie", "Rishikesh", "Haridwar"],
    attractions: [
      { name: "Valley of Flowers", type: "Nature", description: "UNESCO site with alpine flowers" },
      { name: "Rishikesh", type: "Adventure", description: "Yoga capital and river rafting hub" },
      { name: "Nainital Lake", type: "Nature", description: "Scenic pear-shaped lake in hills" },
      { name: "Haridwar Ganga Aarti", type: "Religious", description: "Evening prayer ceremony on Ganges" }
    ],
    bestTime: "March to June, September to November",
    famousFor: ["Pilgrimage", "Yoga", "Trekking", "Adventure Sports"]
  },
  {
    name: "Tamil Nadu",
    tagline: "Temple State",
    icon: Building,
    cities: ["Chennai", "Ooty", "Kodaikanal", "Madurai"],
    attractions: [
      { name: "Meenakshi Temple", type: "Religious", description: "Ancient temple with towering gopurams" },
      { name: "Ooty Hill Station", type: "Nature", description: "Queen of hill stations with toy train" },
      { name: "Mahabalipuram", type: "Historical", description: "Shore temples and rock carvings" },
      { name: "Marina Beach", type: "Beach", description: "World's second longest urban beach" }
    ],
    bestTime: "November to February",
    famousFor: ["Temples", "Hill Stations", "Classical Arts", "Filter Coffee"]
  },
  {
    name: "West Bengal",
    tagline: "Cultural Capital",
    icon: Mountain,
    cities: ["Kolkata", "Darjeeling", "Kalimpong", "Sundarbans"],
    attractions: [
      { name: "Victoria Memorial", type: "Historical", description: "White marble building with museum" },
      { name: "Darjeeling Tea Gardens", type: "Nature", description: "Scenic tea estates with mountain views" },
      { name: "Sundarbans", type: "Wildlife", description: "Mangrove forest and Bengal tiger habitat" },
      { name: "Howrah Bridge", type: "Landmark", description: "Iconic cantilever bridge over Hooghly" }
    ],
    bestTime: "October to March",
    famousFor: ["Culture", "Tea", "Sweets", "Literature"]
  }
];

const Explore = () => {
  const navigate = useNavigate();
  const [selectedState, setSelectedState] = useState<string | null>(null);

  const stateInfo = selectedState ? STATES_DATA.find(s => s.name === selectedState) : null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-accent/5">
      {/* Header */}
      <section className="bg-gradient-to-r from-primary via-accent to-secondary py-16 px-4">
        <div className="max-w-7xl mx-auto text-center text-white">
          <h1 className="text-5xl font-bold mb-4">Explore India</h1>
          <p className="text-xl text-white/90">Discover incredible destinations across the country</p>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 py-12">
        {!selectedState ? (
          <>
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold mb-2">Choose Your Destination</h2>
              <p className="text-muted-foreground">Select a state to discover its attractions</p>
            </div>

            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {STATES_DATA.map((state) => {
                const IconComponent = state.icon;
                return (
                  <Card
                    key={state.name}
                    className="p-6 cursor-pointer hover:shadow-2xl transition-all hover:-translate-y-2"
                    onClick={() => setSelectedState(state.name)}
                  >
                    <div className="flex items-center gap-4 mb-4">
                      <div className="w-16 h-16 bg-gradient-to-br from-primary to-accent rounded-full flex items-center justify-center">
                        <IconComponent className="w-8 h-8 text-white" />
                      </div>
                      <div>
                        <h3 className="text-2xl font-bold">{state.name}</h3>
                        <p className="text-sm text-muted-foreground">{state.tagline}</p>
                      </div>
                    </div>

                    <div className="space-y-3 mb-4">
                      <div className="flex items-start gap-2">
                        <MapPin className="w-4 h-4 text-primary mt-1 flex-shrink-0" />
                        <div>
                          <p className="text-sm font-semibold">Popular Cities</p>
                          <p className="text-sm text-muted-foreground">{state.cities.slice(0, 3).join(", ")}</p>
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-wrap gap-2 mb-4">
                      {state.famousFor.slice(0, 3).map((item) => (
                        <Badge key={item} variant="secondary" className="text-xs">
                          {item}
                        </Badge>
                      ))}
                    </div>

                    <Button variant="outline" className="w-full">
                      Explore {state.name}
                      <ArrowRight className="w-4 h-4 ml-2" />
                    </Button>
                  </Card>
                );
              })}
            </div>
          </>
        ) : (
          <>
            <Button variant="ghost" onClick={() => setSelectedState(null)} className="mb-6">
              <ArrowRight className="w-4 h-4 mr-2 rotate-180" />
              Back to All States
            </Button>

            {stateInfo && (
              <>
                <Card className="p-8 mb-8 shadow-xl">
                  <div className="flex items-center gap-6 mb-6">
                    <div className="w-24 h-24 bg-gradient-to-br from-primary to-accent rounded-full flex items-center justify-center">
                      <stateInfo.icon className="w-12 h-12 text-white" />
                    </div>
                    <div>
                      <h1 className="text-4xl font-bold mb-2">{stateInfo.name}</h1>
                      <p className="text-xl text-muted-foreground">{stateInfo.tagline}</p>
                    </div>
                  </div>

                  <div className="grid md:grid-cols-2 gap-6 mb-6">
                    <div>
                      <h3 className="font-semibold mb-2 flex items-center gap-2">
                        <MapPin className="w-5 h-5 text-primary" />
                        Major Cities
                      </h3>
                      <p className="text-muted-foreground">{stateInfo.cities.join(", ")}</p>
                    </div>
                    <div>
                      <h3 className="font-semibold mb-2">Best Time to Visit</h3>
                      <p className="text-muted-foreground">{stateInfo.bestTime}</p>
                    </div>
                  </div>

                  <div className="mb-6">
                    <h3 className="font-semibold mb-3">Famous For</h3>
                    <div className="flex flex-wrap gap-2">
                      {stateInfo.famousFor.map((item) => (
                        <Badge key={item} variant="secondary">{item}</Badge>
                      ))}
                    </div>
                  </div>

                  <Button variant="hero" onClick={() => navigate('/planning')} className="w-full md:w-auto">
                    Plan Trip to {stateInfo.name}
                  </Button>
                </Card>

                <h2 className="text-3xl font-bold mb-6">Top Attractions</h2>
                <div className="grid md:grid-cols-2 gap-6">
                  {stateInfo.attractions.map((attraction, idx) => (
                    <Card key={idx} className="p-6 hover:shadow-lg transition-shadow">
                      <div className="flex justify-between items-start mb-3">
                        <h3 className="text-xl font-bold">{attraction.name}</h3>
                        <Badge>{attraction.type}</Badge>
                      </div>
                      <p className="text-muted-foreground">{attraction.description}</p>
                    </Card>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default Explore;
