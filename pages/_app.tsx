import "../styles/globals.css";
import type { AppProps } from "next/app";
import Head from "next/head";

function MyApp({ Component, pageProps }: AppProps) {
	return (
		<>
		<Head>
			<title>Estado de servicios de OSM.lat</title>
			<meta name="description" content="Página de estado de los servicios de OSM.lat - OpenStreetMap Latinoamérica" />
		</Head>
			<Component {...pageProps} />
		</>
	);
}

export default MyApp;
