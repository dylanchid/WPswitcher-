import { useState } from "react";
import Head from "next/head";
import dynamic from "next/dynamic";
import mapboxgl from "mapbox-gl";
import { useEffect, useRef } from "react";

// Set your Mapbox token here or load it from an environment variable
mapboxgl.accessToken = "pk.eyJ1IjoiZXhhbXBsZXVzZXIiLCJhIjoiY2xleGF1b3Z2MDJodDNpbnY2em5yb2FlNSJ9.lnFKaGqtb9PvBzcuCzfxAw";

/**
 * Map component using Mapbox GL JS.
 */
function InteractiveMap({ onRegionSelect }: { onRegionSelect: (region: string) => void }) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<mapboxgl.Map | null>(null);

  useEffect(() => {
    if (!mapContainer.current || mapInstance.current) return;

    mapInstance.current = new mapboxgl.Map({
      container: mapContainer.current,
      style: "mapbox://styles/mapbox/light-v11",
      center: [-98, 38.88], // Center of the US
      zoom: 3,
    });

    mapInstance.current.on("load", () => {
      // Example interactivity using click event — customize with real region data later
      mapInstance.current?.on("click", (e) => {
        const lngLat = e.lngLat;
        const guessedRegion = lngLat.lng < -100 ? "West" : "East";
        onRegionSelect(guessedRegion);
      });
    });
  }, [onRegionSelect]);

  return <div ref={mapContainer} className="w-full h-96 rounded shadow-inner" />;
}

// Wrap with Next.js dynamic to disable SSR
const Map = dynamic(() => Promise.resolve(InteractiveMap), { ssr: false });

/**
 * Placeholder Card component.
 */
function Card({ children }: { children: React.ReactNode }) {
  return <div className="bg-white rounded shadow-md border border-gray-200">{children}</div>;
}

/**
 * Placeholder CardContent component.
 */
function CardContent({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`p-4 ${className}`}>{children}</div>;
}

/**
 * Placeholder Button component.
 */
function Button({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <button className={`bg-blue-600 hover:bg-blue-700 text-white font-semibold px-4 py-2 rounded ${className}`}>{children}</button>;
}

/**
 * Home Page
 * Displays an interactive map with a sample region card.
 */
export default function Home() {
  const [region, setRegion] = useState<string | null>(null);

  return (
    <>
      <Head>
        <title>FieldLore - Community Sports History</title>
        <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
      </Head>
      <main className="min-h-screen p-6 bg-gray-100">
        <h1 className="text-4xl font-bold mb-4">Explore Sports History by Region</h1>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <Map onRegionSelect={setRegion} />
          </div>
          <div>
            {region ? (
              <Card>
                <CardContent>
                  <h2 className="text-xl font-semibold">{region}</h2>
                  <p className="text-sm text-gray-600">
                    Stories, games, and athletes from {region}. Click below to view the full archive.
                  </p>
                  <Button className="mt-4">View Region</Button>
                </CardContent>
              </Card>
            ) : (
              <Card>
                <CardContent className="text-gray-500">
                  Select a region on the map to begin exploring.
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </main>
    </>
  );
}
