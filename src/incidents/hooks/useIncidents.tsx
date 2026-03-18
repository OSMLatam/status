import { useState, useEffect, useRef } from "react";
import Incident from "../types/Incident";
import MonthlyIncident from "../types/MonthlyIncident";

function useIncidents() {
    const [data, setData] = useState<MonthlyIncident[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState();
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
                const response = await fetch("https://api.github.com/repos/OSMLatam/status/issues?per_page=20&state=all&labels=incident");
                const issues = await response.json();
                const monthlyIncident = devideMonthly(issues.map((issue: any) => ({
                    id: issue.id,
                    title: issue.title,
                    desciption: issue.body,
                    status: issue.state,
                    created_at: issue.created_at,
                    closed_at: issue.closed_at,
                    labels: issue.labels.map((label: any) => label.name)
                })));
                if (!cancelled) setData(monthlyIncident);
            } catch (e: any) {
                if (!cancelled) setError(e);
            } finally {
                if (!cancelled) {
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

    return [data, isLoading, error];
}

function devideMonthly(issues: any[]) {

    const incidents: MonthlyIncident[] = [];
    var monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    Object.values(issues.reduce((r, date) => {
        const [year, month, day] = date.created_at.substr(0, 10).split('-');
        const key = `${year}_${month}`;
        r[key] = r[key] || { month: `${monthNames[parseInt(month) - 1]} ${year}`, incidents: [] };
        r[key].incidents.push(date);
        console.log('issues', r)
        return r;
    }, {})).forEach((month: any) => {
        incidents.push({
            month: month.month,
            incidents: month.incidents
        });
    });

    return incidents;
}


export default useIncidents;
