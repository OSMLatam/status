import { useState, useEffect, useRef } from "react";
import { Status } from "../../utils/constants";
import ServiceStatus from "../types/ServiceStatus";
import SystemStatus from "../types/SystemStatus";

function useSystemStatus() {
    const [systemStatus, setSystemStatus] = useState<SystemStatus>();
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState();
    const [lastCheckedAt, setLastCheckedAt] = useState<string>("");
    const hasLoadedRef = useRef(false);

    useEffect(() => {
        const intervalMs = 5 * 60 * 1000; // 5 minutes
        let isFetching = false;
        let cancelled = false;

        const loadData = async () => {
            if (isFetching) return;
            isFetching = true;
            const shouldToggleLoading = !hasLoadedRef.current;
            if (shouldToggleLoading) setIsLoading(true);
            try {
                const response = await fetch("./urls.cfg");
                const configText = await response.text();
                const configLines = configText.split("\n");
                const services: ServiceStatus[] = [];
                for (let ii = 0; ii < configLines.length; ii++) {
                    const configLine = configLines[ii];
                    const [key, url] = configLine.split("=");
                    if (!key || !url) continue;

                    const status = await logs(key);
                    services.push(status);
                }

                if (services.every((item) => item.status === "success")) {
                    if (!cancelled) {
                        setSystemStatus({
                            title: "All System Operational",
                            status: Status.OPERATIONAL,
                            datetime: services[0].date
                        });
                    }
                } else if (services.every((item) => item.status === "failed")) {
                    if (!cancelled) {
                        setSystemStatus({
                            title: "Outage",
                            status: Status.OUTAGE,
                            datetime: services[0].date
                        });
                    }
                } else if (services.every((item) => item.status === "unknown")) {
                    if (!cancelled) {
                        setSystemStatus({
                            title: "Unknown",
                            status: Status.UNKNOWN,
                            datetime: services[0]?.date ?? ""
                        });
                    }
                } else {
                    if (!cancelled) {
                        setSystemStatus({
                            title: "Partial Outage",
                            status: Status.PARTIAL_OUTAGE,
                            datetime: services[0].date
                        });
                    }
                }
            } catch (e: any) {
                if (!cancelled) setError(e);
            } finally {
                if (!cancelled) {
                    setLastCheckedAt(new Date().toISOString());
                    hasLoadedRef.current = true;
                }
                if (shouldToggleLoading && !cancelled) setIsLoading(false);
                isFetching = false;
            }
        };

        loadData();
        const intervalId = window.setInterval(loadData, intervalMs);

        return () => {
            cancelled = true;
            window.clearInterval(intervalId);
        };
    }, []);

    return { systemStatus, isLoading, error, lastCheckedAt };
}

async function logs(key: string): Promise<ServiceStatus> {
    const response = await fetch(`https://raw.githubusercontent.com/OSMLatam/status/main/public/status/${key}_report.log`);
    const text = await response.text();
    const lines = text.split("\n");
    try {
        const line = lines[lines.length - 2];
        const [created_at, status, _] = line.split(", ");
        return {
            name: key,
            status: status,
            date: created_at,
        };
    } catch (e) {
        return {
            name: key,
            status: "unknown",
            date: undefined,
        };
    }
}

export default useSystemStatus;
