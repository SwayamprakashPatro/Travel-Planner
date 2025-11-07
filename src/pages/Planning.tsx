import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { CalendarIcon, MapPin, Users, DollarSign } from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";

const INDIAN_STATES = [
  "Andhra Pradesh", "Goa", "Gujarat", "Karnataka", "Kerala", "Maharashtra", 
  "Rajasthan", "Tamil Nadu", "Uttarakhand", "West Bengal"
];

const CITIES_BY_STATE: Record<string, string[]> = {
  "Goa": ["Panaji", "Calangute", "Baga", "Anjuna"],
  "Kerala": ["Kochi", "Munnar", "Alleppey", "Kovalam"],
  "Rajasthan": ["Jaipur", "Udaipur", "Jodhpur", "Jaisalmer"],
  "Karnataka": ["Bangalore", "Mysore", "Coorg", "Hampi"],
  "Maharashtra": ["Mumbai", "Pune", "Lonavala", "Mahabaleshwar"],
  "Tamil Nadu": ["Chennai", "Ooty", "Kodaikanal", "Madurai"],
  "Gujarat": ["Ahmedabad", "Surat", "Vadodara", "Dwarka"],
  "Uttarakhand": ["Nainital", "Mussoorie", "Rishikesh", "Haridwar"],
  "West Bengal": ["Kolkata", "Darjeeling", "Kalimpong", "Sundarbans"],
  "Andhra Pradesh": ["Visakhapatnam", "Tirupati", "Vijayawada", "Araku Valley"]
};

const Planning = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [selectedState, setSelectedState] = useState("");
  const [selectedCities, setSelectedCities] = useState<string[]>([]);
  const [numPeople, setNumPeople] = useState("");
  const [budget, setBudget] = useState("");
  const [startDate, setStartDate] = useState<Date>();

  const handleCityToggle = (city: string) => {
    setSelectedCities(prev => 
      prev.includes(city) ? prev.filter(c => c !== city) : [...prev, city]
    );
  };

  const handleGenerateItinerary = () => {
    const tripData = {
      state: selectedState,
      cities: selectedCities,
      numPeople: parseInt(numPeople),
      budget: parseInt(budget),
      startDate: startDate?.toISOString()
    };
    localStorage.setItem('currentTrip', JSON.stringify(tripData));
    navigate('/itinerary');
  };

  const canProceed = () => {
    if (step === 1) return selectedState !== "";
    if (step === 2) return selectedCities.length > 0;
    if (step === 3) return numPeople && budget;
    if (step === 4) return startDate !== undefined;
    return false;
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-accent/10 py-12 px-4">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
            Plan Your Dream Trip
          </h1>
          <p className="text-muted-foreground">Step {step} of 4</p>
        </div>

        {/* Progress Bar */}
        <div className="mb-8">
          <div className="h-2 bg-muted rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-primary to-accent transition-all duration-500"
              style={{ width: `${(step / 4) * 100}%` }}
            />
          </div>
        </div>

        <Card className="p-8 shadow-xl">
          {step === 1 && (
            <div className="space-y-6">
              <div className="flex items-center gap-3 mb-6">
                <MapPin className="w-8 h-8 text-primary" />
                <h2 className="text-2xl font-semibold">Choose Your State</h2>
              </div>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                {INDIAN_STATES.map(state => (
                  <button
                    key={state}
                    onClick={() => setSelectedState(state)}
                    className={cn(
                      "p-4 rounded-lg border-2 transition-all hover:scale-105",
                      selectedState === state
                        ? "border-primary bg-primary/10 shadow-md"
                        : "border-border hover:border-primary/50"
                    )}
                  >
                    {state}
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-6">
              <div className="flex items-center gap-3 mb-6">
                <MapPin className="w-8 h-8 text-secondary" />
                <h2 className="text-2xl font-semibold">Select Cities in {selectedState}</h2>
              </div>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                {CITIES_BY_STATE[selectedState]?.map(city => (
                  <button
                    key={city}
                    onClick={() => handleCityToggle(city)}
                    className={cn(
                      "p-4 rounded-lg border-2 transition-all hover:scale-105",
                      selectedCities.includes(city)
                        ? "border-secondary bg-secondary/10 shadow-md"
                        : "border-border hover:border-secondary/50"
                    )}
                  >
                    {city}
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-6">
              <div className="flex items-center gap-3 mb-6">
                <Users className="w-8 h-8 text-accent" />
                <h2 className="text-2xl font-semibold">Trip Details</h2>
              </div>
              <div className="space-y-4">
                <div>
                  <Label htmlFor="people" className="text-lg">Number of People</Label>
                  <Input
                    id="people"
                    type="number"
                    min="1"
                    placeholder="Enter number of travelers"
                    value={numPeople}
                    onChange={(e) => setNumPeople(e.target.value)}
                    className="mt-2 h-12 text-lg"
                  />
                </div>
                <div>
                  <Label htmlFor="budget" className="text-lg">Budget Per Person (₹)</Label>
                  <Input
                    id="budget"
                    type="number"
                    min="1000"
                    placeholder="Enter budget in rupees"
                    value={budget}
                    onChange={(e) => setBudget(e.target.value)}
                    className="mt-2 h-12 text-lg"
                  />
                </div>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="space-y-6">
              <div className="flex items-center gap-3 mb-6">
                <CalendarIcon className="w-8 h-8 text-primary" />
                <h2 className="text-2xl font-semibold">Choose Start Date</h2>
              </div>
              <div className="flex justify-center">
                <Popover>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      className={cn(
                        "w-full max-w-md h-14 text-lg justify-start",
                        !startDate && "text-muted-foreground"
                      )}
                    >
                      <CalendarIcon className="mr-2 h-5 w-5" />
                      {startDate ? format(startDate, "PPP") : "Pick a date"}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0" align="center">
                    <Calendar
                      mode="single"
                      selected={startDate}
                      onSelect={setStartDate}
                      disabled={(date) => date < new Date()}
                      initialFocus
                      className="pointer-events-auto"
                    />
                  </PopoverContent>
                </Popover>
              </div>
            </div>
          )}

          <div className="flex gap-4 mt-8">
            {step > 1 && (
              <Button
                variant="outline"
                onClick={() => setStep(step - 1)}
                className="flex-1 h-12 text-lg"
              >
                Back
              </Button>
            )}
            {step < 4 ? (
              <Button
                variant="hero"
                onClick={() => setStep(step + 1)}
                disabled={!canProceed()}
                className="flex-1 h-12 text-lg"
              >
                Next
              </Button>
            ) : (
              <Button
                variant="sunset"
                onClick={handleGenerateItinerary}
                disabled={!canProceed()}
                className="flex-1 h-12 text-lg"
              >
                Generate Itinerary
              </Button>
            )}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default Planning;
