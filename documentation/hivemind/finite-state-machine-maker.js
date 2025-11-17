// --- CSV → FSM JSON Builder with Always-True Transitions ---

function parseCSV(csvString) {
    const rows = csvString.trim().split("\n");
    const headers = rows.shift().split(",").map(h => h.trim());

    return rows.map(row => {
        const fields = row.split(",").map(f => f.trim());
        const obj = {};
        headers.forEach((h, i) => (obj[h] = fields[i]));
        return obj;
    });
}

function buildFSM(csvString) {
    const rows = parseCSV(csvString);

    const Q = new Set();
    const Sigma = new Set();
    const delta = {};
    let q0 = null;
    const F = new Set();

    rows.forEach(r => {
        Q.add(r.state);
        Q.add(r.next_state);
        Sigma.add(r.input);

        if (!delta[r.state]) delta[r.state] = [];
        delta[r.state].push({
            input: r.input,
            next: r.next_state,
            condition: "true" // transition always true
        });

        if (r.is_start === "true") {
            q0 = r.state;
        }

        if (r.is_accept === "true") {
            F.add(r.state);
        }
    });

    return {
        states: [...Q],
        alphabet: [...Sigma],
        start_state: q0,
        accept_states: [...F],
        transitions: delta
    };
}

// Example usage:
const csv = `
state,input,next_state,is_start,is_accept
A,x,B,true,false
B,y,C,false,false
C,z,A,false,true
`;

console.log(JSON.stringify(buildFSM(csv), null, 2));
