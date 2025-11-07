import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Index from "./pages/Index";
import Auth from "./pages/Auth";
import Planning from "./pages/Planning";
import Itinerary from "./pages/Itinerary";
import Selection from "./pages/Selection";
import Payment from "./pages/Payment";
import MyTrips from "./pages/MyTrips";
import TripDetails from "./pages/TripDetails";
import Explore from "./pages/Explore";
import NotFound from "./pages/NotFound";
import DevDbStatus from "./pages/DevDbStatus";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Index />} />
          <Route path="/auth" element={<Auth />} />
          <Route path="/explore" element={<Explore />} />
          <Route path="/planning" element={<Planning />} />
          <Route path="/itinerary" element={<Itinerary />} />
          <Route path="/selection" element={<Selection />} />
          <Route path="/payment" element={<Payment />} />
          <Route path="/my-trips" element={<MyTrips />} />
          <Route path="/trip/:id" element={<TripDetails />} />
          <Route path="/dev-db-status" element={<DevDbStatus />} />
          {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
