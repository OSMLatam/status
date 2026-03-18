import { useState, useEffect, useRef } from "react";
import Service from '../types/Service';
import Log from "../types/Log";
import LogDaySummary from "../types/LogDaySummary";
import { Status } from "../../utils/constants";

function useServices() {
    const [data, setData] = useState<Service[]>([]);
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

                const services: Service[] = [];
                for (let ii = 0; ii < configLines.length; ii++) {
                    const configLine = configLines[ii];
                    const [key, url] = configLine.split("=");
                    if (!key || !url) continue;

                    const log = await logs(key);
                    if (log.length > 0) {
                        services.push({ id: ii, name: key, status: log[log.length - 1].status, logs: log });
                    } else {
                        services.push({ id: ii, name: key, status: "unknown", logs: log });
                    }
                }

                if (!cancelled) setData(services as Service[]);
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

        // Initial load + polling
        loadData();
        const intervalId = window.setInterval(loadData, intervalMs);

        return () => {
            cancelled = true;
            window.clearInterval(intervalId);
        };
    }, []);

    return [data, isLoading, error, lastCheckedAt];
}

async function logs(key: string): Promise<LogDaySummary[]> {
    const response = await fetch(`https://raw.githubusercontent.com/OSMLatam/status/main/public/status/${key}_report.log`);

    const text = await response.text();
    const lines = text.split("\n");
    const logs: Log[] = [];
    const logDaySummary: LogDaySummary[] = [];

    lines.forEach((line: string) => {
        const [created_at, status, response_time] = line.split(", ");
        logs.push({ id: created_at, response_time, status, created_at })
    })

    const prepareSummary = Object.values(logs.reduce((r: any, date) => {
        const [year, month, day] = date.created_at.substr(0, 10).split('-');
        const key = `${day}_${month}_${year}`;
        r[key] = r[key] || { date: date.created_at, logs: [] };
        r[key].logs.push(date);
        return r;
    }, {}));


    prepareSummary.forEach((logSummary: any) => {
        var avg_response_time = 0

        logSummary.logs.forEach((log: Log) => {
            if (log.response_time) {
                avg_response_time += Number(log.response_time.replaceAll('s', ''));
            }
        });

        let status = ""
        if (logSummary.logs.length === 0) {
            status = "unknown"
        } else if (logSummary.logs.every((item:any)=> item.status === 'success')) {
            status = Status.OPERATIONAL
        } else if (logSummary.logs.every((item:any)=> item.status === 'failed')) {
            status = Status.OUTAGE
        } else {
            status = Status.PARTIAL_OUTAGE
        }

        logDaySummary.push({
            avg_response_time: avg_response_time / logSummary.logs.length,
            current_status: logSummary.logs[logSummary.logs.length - 1].status,
            date: logSummary.date.substr(0, 10),
            status: status
        })
    })


    return fillData(logDaySummary);
}

function fillData(data: LogDaySummary[]): LogDaySummary[] {
    const logDaySummary: LogDaySummary[] = [];
    var today = new Date();

    // Last 90 days including today (no "tomorrow" off-by-one).
    for (var i = 0; i < 90; i += 1) {
        const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
        const summary = data.find((item) => item.date === d.toISOString().substr(0, 10));
        logDaySummary.push({
            avg_response_time: summary?.avg_response_time || 0,
            current_status: summary?.current_status || "unknown",
            date: d.toISOString().substr(0, 10),
            status: summary?.status || "unknown"
        })
    }

    return logDaySummary.reverse();
}


export default useServices;
