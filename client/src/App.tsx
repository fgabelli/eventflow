import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import NotFound from "@/pages/NotFound";
import { Route, Switch, Redirect } from "wouter";
import ErrorBoundary from "./components/ErrorBoundary";
import { ThemeProvider } from "./contexts/ThemeContext";
import { SupabaseAuthProvider, useSupabaseAuth } from "./contexts/SupabaseAuthContext";
import { DashboardLayout } from "./components/layout/DashboardLayout";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Events from "./pages/Events";
import Attendees from "./pages/Attendees";
import CheckIn from "./pages/CheckIn";
import EventForm from "./pages/EventForm";
import AttendeeForm from "./pages/AttendeeForm";
import Categories from "./pages/Categories";

function ProtectedRoute({ component: Component, ...rest }: any) {
  const { user, loading } = useSupabaseAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (!user) {
    return <Redirect to="/login" />;
  }

  return (
    <DashboardLayout>
      <Component {...rest} />
    </DashboardLayout>
  );
}

function Router() {
  const { user, loading } = useSupabaseAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <Switch>
      <Route path="/login">
        {user ? <Redirect to="/" /> : <Login />}
      </Route>
      <Route path="/" component={(props) => <ProtectedRoute component={Home} {...props} />} />
      <Route path="/events" component={(props) => <ProtectedRoute component={Events} {...props} />} />
      <Route path="/attendees" component={(props) => <ProtectedRoute component={Attendees} {...props} />} />
      <Route path="/checkin" component={(props) => <ProtectedRoute component={CheckIn} {...props} />} />
      <Route path="/events/:id" component={(props) => <ProtectedRoute component={EventForm} {...props} />} />
      <Route path="/attendees/:id" component={(props) => <ProtectedRoute component={AttendeeForm} {...props} />} />
      <Route path="/categories" component={(props) => <ProtectedRoute component={Categories} {...props} />} />
      <Route path="/404" component={NotFound} />
      <Route component={NotFound} />
    </Switch>
  );
}

// NOTE: About Theme
// - First choose a default theme according to your design style (dark or light bg), than change color palette in index.css
//   to keep consistent foreground/background color across components
// - If you want to make theme switchable, pass `switchable` ThemeProvider and use `useTheme` hook

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider defaultTheme="light">
        <SupabaseAuthProvider>
          <TooltipProvider>
            <Toaster />
            <Router />
          </TooltipProvider>
        </SupabaseAuthProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
