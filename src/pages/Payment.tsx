import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { CreditCard, Lock, CheckCircle } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/lib/supabase";

const Payment = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [totalCost, setTotalCost] = useState(0);

  useEffect(() => {
    const tripData = localStorage.getItem("currentTrip");
    if (!tripData) {
      navigate("/planning");
      return;
    }

    const trip = JSON.parse(tripData);
    // Mock calculation
    const mockTotal = trip.numPeople * trip.budget;
    setTotalCost(mockTotal);
  }, [navigate]);

  const handlePayment = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    // Simulate payment processing and persist to Supabase
    try {
      const tripDataRaw = localStorage.getItem("currentTrip");
      const selectionsRaw = localStorage.getItem("tripSelections");
      if (!tripDataRaw) throw new Error("No current trip in localStorage");

      const tripData = JSON.parse(tripDataRaw);
      const selections = selectionsRaw ? JSON.parse(selectionsRaw) : {};

      // Determine current authenticated user (if any) and use their id
      let userId: string | null = null;
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        userId = user?.id ?? null;
      } catch (e) {
        // ignore - user may be unauthenticated
      }

      // 1) Insert trip record
      const { data: tripInsert, error: tripError } = await supabase
        .from("trips")
        .insert({
          user_id: userId,
          title: `${tripData.state || "Trip"} Trip`,
          state: tripData.state || null,
          cities: tripData.cities || null,
          start_date: tripData.startDate
            ? new Date(tripData.startDate).toISOString().slice(0, 10)
            : null,
          // schema uses budget_per_person
          budget_per_person: tripData.budget || null,
          // total_days exists on trips; store number of days if available
          total_days: tripData.cities ? tripData.cities.length : null,
        })
        .select()
        .single();

      if (tripError) throw tripError;

      const tripId = tripInsert?.id;

      // 2) Insert booking record tied to trip
      const mockTotal = tripData.numPeople * tripData.budget;
      const { data: bookingInsert, error: bookingError } = await supabase
        .from("bookings")
        .insert({
          trip_id: tripId,
          user_id: userId,
          // Insert as 'pending' so bookings are not auto-confirmed; confirmation
          // can be handled by an admin action or payment webhook later.
          status: "pending",
          booked_at: new Date().toISOString(),
          // the bookings table in schema does not include a 'selections' column;
          // keep only the columns that exist
          total_amount: Math.round(mockTotal * 1),
        })
        .select()
        .single();

      if (bookingError) throw bookingError;

      // Clear local state and navigate
      localStorage.removeItem("currentTrip");
      localStorage.removeItem("tripSelections");

      toast.success("Payment Successful!", {
        description: "Your trip has been booked and saved to the database.",
      });

      setLoading(false);
      navigate("/my-trips");
    } catch (err: any) {
      // eslint-disable-next-line no-console
      console.error("Payment/store failed", err);
      // Try to extract a helpful message from the Supabase error object
      let msg = "Payment failed. Please try again.";
      try {
        if (!err) throw null;
        if (typeof err === "string") msg = err;
        else if (err.message) msg = err.message;
        else if (err.error) msg = err.error;
        else if (err.response && err.response.text)
          msg = await err.response.text();
        else msg = JSON.stringify(err);
      } catch (e) {
        // ignore
      }
      toast.error(msg);
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-muted/20 to-primary/10 py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold mb-2 bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
            Complete Your Booking
          </h1>
          <p className="text-muted-foreground">Secure payment gateway</p>
        </div>

        <div className="space-y-6">
          <Card className="p-6 bg-gradient-to-br from-primary/10 to-accent/10 border-primary/20">
            <h2 className="text-2xl font-bold mb-4">Order Summary</h2>
            <div className="space-y-2 text-lg">
              <div className="flex justify-between">
                <span>Trip Package</span>
                <span className="font-semibold">₹{totalCost}</span>
              </div>
              <div className="flex justify-between text-muted-foreground">
                <span>Taxes & Fees</span>
                <span>₹{Math.round(totalCost * 0.18)}</span>
              </div>
              <div className="border-t border-border pt-2 flex justify-between text-xl font-bold">
                <span>Total Amount</span>
                <span className="text-primary">
                  ₹{Math.round(totalCost * 1.18)}
                </span>
              </div>
            </div>
          </Card>

          <Card className="p-6">
            <form onSubmit={handlePayment} className="space-y-6">
              <div className="flex items-center gap-2 mb-6">
                <CreditCard className="w-6 h-6 text-primary" />
                <h2 className="text-xl font-semibold">Payment Details</h2>
              </div>

              <div>
                <Label htmlFor="name">Cardholder Name</Label>
                <Input
                  id="name"
                  placeholder="John Doe"
                  required
                  className="mt-2"
                />
              </div>

              <div>
                <Label htmlFor="card">Card Number</Label>
                <Input
                  id="card"
                  placeholder="1234 5678 9012 3456"
                  maxLength={19}
                  required
                  className="mt-2"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="expiry">Expiry Date</Label>
                  <Input
                    id="expiry"
                    placeholder="MM/YY"
                    maxLength={5}
                    required
                    className="mt-2"
                  />
                </div>
                <div>
                  <Label htmlFor="cvv">CVV</Label>
                  <Input
                    id="cvv"
                    placeholder="123"
                    maxLength={3}
                    required
                    className="mt-2"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2 p-4 bg-muted/50 rounded-lg">
                <Lock className="w-5 h-5 text-accent" />
                <p className="text-sm text-muted-foreground">
                  Your payment information is encrypted and secure
                </p>
              </div>

              <Button
                type="submit"
                variant="hero"
                disabled={loading}
                className="w-full h-14 text-lg"
              >
                {loading ? (
                  <span className="flex items-center gap-2">Processing...</span>
                ) : (
                  <span className="flex items-center gap-2">
                    <CheckCircle className="w-5 h-5" />
                    Pay ₹{Math.round(totalCost * 1.18)}
                  </span>
                )}
              </Button>
            </form>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default Payment;
