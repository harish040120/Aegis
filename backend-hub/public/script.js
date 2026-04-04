// Initialize Map
const map = L.map('map').setView([13.0827, 80.2707], 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
}).addTo(map);

let simMarker = null;
let zoneCircles = { rain: null, flood: null, earthquake: null };

// Load Initial Data
window.onload = () => {
    loadWorkers();
    loadParams();
};

async function loadWorkers() {
    try {
        const response = await fetch('/api/workers');
        const workers = await response.json();
        const select = document.getElementById('worker-select');
        select.innerHTML = '';
        
        workers.forEach(w => {
            const option = document.createElement('option');
            option.value = w.worker_id;
            option.textContent = `${w.worker_id} — ${w.name || 'Unknown'} (${w.zone || 'N/A'})`;
            select.appendChild(option);
        });
    } catch (e) {
        console.error('Failed to load workers:', e);
    }
}

async function applyScenario(key, btnElement) {
    document.querySelectorAll('.scenario-btn').forEach(btn => btn.classList.remove('active'));
    if (btnElement) btnElement.classList.add('active');

    const workerId = document.getElementById('worker-select').value;

    await fetch('/api/scenario', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scenario_key: key, worker_id: workerId })
    });

    await loadParams();
    await fetchRiskData(); 
}

async function syncWorker() {
    const workerId = document.getElementById('worker-select').value;
    const workerCoords = {
        W001: { lat: 13.0827, lon: 80.2707 },
        W002: { lat: 13.0345, lon: 80.2442 },
        W003: { lat: 13.1123, lon: 80.2981 },
        W004: { lat: 13.0678, lon: 80.2356 },
        W005: { lat: 11.0168, lon: 76.9558 }
    };
    
    const coords = workerCoords[workerId];
    if (coords) {
        document.getElementById('sim_lat').value = coords.lat;
        document.getElementById('sim_lon').value = coords.lon;
    }
    
    await fetch('/api/scenario', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ worker_id: workerId })
    });
    await fetchRiskData();
}

// --- Parameter Management ---
async function loadParams() {
    const res = await fetch('/api/params');
    const params = await res.json();
    const list = document.getElementById('param-list');
    list.innerHTML = '';
    Object.entries(params).forEach(([name, p]) => {
        list.innerHTML += `
            <div class="param-row">
                <div style="font-weight: 500; color: #495057;">${name.replace(/_/g, ' ')}</div>
                <input type="number" value="${p.value}" style="padding: 4px; margin: 0;" onchange="updateParam('${name}', this.value, ${p.min}, ${p.max})">
                <div style="text-align:center; color: #adb5bd; font-size: 0.7rem;">${p.min}</div>
                <div style="text-align:center; color: #adb5bd; font-size: 0.7rem;">${p.max}</div>
            </div>`;
    });
}

async function updateParam(name, value, min, max) {
    await fetch('/api/params', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, value })
    });
}

// --- Risk Orchestration ---
async function fetchRiskData() {
    const lat = document.getElementById('sim_lat').value;
    const lon = document.getElementById('sim_lon').value;
    const workerId = document.getElementById('worker-select').value;
    
    if (simMarker) map.removeLayer(simMarker);
    simMarker = L.marker([lat, lon]).addTo(map).bindPopup(`Target: ${workerId}`).openPopup();
    map.setView([lat, lon], 12);

    const btn = document.querySelector('.btn-primary');
    btn.innerText = 'ORCHESTRATING...';

    try {
        const response = await fetch(`/api/risk-data?lat=${lat}&lon=${lon}&worker_id=${workerId}`);
        const result = await response.json();

        document.getElementById('results-card').style.display = 'block';
        document.getElementById('raw-json').innerText = JSON.stringify(result, null, 2);

        const loc = result.location;
        const weather = result.external_disruption.weather;
        const aq = result.external_disruption.air_quality;
        const metrics = result.business_impact.metrics;

        let alertClass = 'bg-live', alertLabel = 'LIVE: STABLE';
        if (metrics.order_drop_pct > 70) { alertClass = 'bg-breach'; alertLabel = 'BREACH: SEVERE DISRUPTION'; }
        else if (metrics.order_drop_pct > 30) { alertClass = 'bg-watch'; alertLabel = 'WATCH: ELEVATED RISK'; }

        document.getElementById('summary').innerHTML = `
            <div class="card" style="border-top: 4px solid ${alertClass === 'bg-breach' ? '#DC3545' : (alertClass === 'bg-watch' ? '#FF6B35' : '#00A4A4')}">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px;">
                    <div>
                        <h2 style="margin: 0; color: #212529; font-size: 1.1rem;">${loc.place_name || "Location Analyzed"}</h2>
                        <div style="font-size: 0.8rem; color: #0066CC; font-weight: bold; margin-top: 4px;">Zone: ${loc.zone}</div>
                        <small style="color: #6c757d;">COORD: ${loc.lat}, ${loc.lon} | AGENT: ${result.worker_id}</small>
                    </div>
                    <span class="alert-badge ${alertClass}">${alertLabel}</span>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
                    <div style="background: #f8f9fa; padding: 15px; border-radius: 4px; border-left: 3px solid #0066CC;">
                        <h4 style="margin: 0 0 10px 0; font-size: 0.7rem; color: #adb5bd; text-transform: uppercase;">Environmental Signal</h4>
                        <div style="font-weight: 700; color: #002B54; font-size: 1.2rem;">${weather.temp}°C</div>
                        <div style="font-size: 0.85rem; color: #495057; margin-top: 8px;">
                            🌧️ Rain: ${weather.rain_1h}mm | 🌫️ PM2.5: ${aq.pm25} | 🌫️ PM10: ${aq.pm10}
                        </div>
                    </div>
                    <div style="background: #f8f9fa; padding: 15px; border-radius: 4px; border-left: 3px solid ${alertClass === 'bg-breach' ? '#DC3545' : (alertClass === 'bg-watch' ? '#FF6B35' : '#00A4A4')}">
                        <h4 style="margin: 0 0 10px 0; font-size: 0.7rem; color: #adb5bd; text-transform: uppercase;">Business Metric Loss</h4>
                        <div style="font-weight: 700; color: ${alertClass === 'bg-breach' ? '#DC3545' : (alertClass === 'bg-watch' ? '#FF6B35' : '#212529')}; font-size: 1.2rem;">
                            -${metrics.order_drop_pct.toFixed(1)}% Orders
                        </div>
                        <div style="font-size: 0.85rem; color: #495057; margin-top: 8px;">
                            📉 Earnings: -${metrics.earnings_drop_pct.toFixed(1)}% | ⏳ Activity: -${metrics.activity_drop_pct.toFixed(1)}%
                        </div>
                    </div>
                </div>
            </div>`;
    } catch (e) { 
        console.error(e); 
        alert('Error fetching risk data: ' + e.message);
    } finally { 
        btn.innerText = 'RUN SYSTEM ANALYSIS'; 
    }
}

// Update zones (placeholder - can be enhanced)
async function updateZones() {
    alert('Zone sync functionality - can be implemented based on needs');
}

// Clear all risks
async function clearAllRisks() {
    document.querySelectorAll('.scenario-btn').forEach(btn => btn.classList.remove('active'));
    await applyScenario('normal');
}

// Test alerts for current scenario
async function testAlerts() {
    const workerId = document.getElementById('worker-select').value;
    const btn = document.querySelector('#test-result').previousElementSibling;
    const originalText = btn.innerText;
    btn.innerText = 'TESTING...';
    
    try {
        const response = await fetch(`/api/test-alerts?worker_id=${workerId}`);
        const result = await response.json();
        
        const testDiv = document.getElementById('test-result');
        testDiv.style.display = 'block';
        
        if (result.has_alerts) {
            const activeAlerts = result.alerts.filter(a => a.active && !a.is_fraud);
            testDiv.innerHTML = `
                <div style="background: #FFF3CD; border: 1px solid #FFDA6A; padding: 10px; border-radius: 4px;">
                    <strong style="color: #856404;">⚠️ ${activeAlerts.length} Alert(s) Detected:</strong>
                    <ul style="margin: 8px 0 0 0; padding-left: 20px; color: #856404;">
                        ${activeAlerts.map(a => `
                            <li>${a.typeLabel} - ${Math.floor(a.trigger_pct * 100)}% payout</li>
                        `).join('')}
                    </ul>
                    <button onclick="triggerPayout()" style="margin-top: 10px; background: #28A745; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer;">
                        🚀 TRIGGER IN APP
                    </button>
                </div>
            `;
            
            // Store alerts for triggering
            window.currentAlerts = activeAlerts;
        } else {
            testDiv.innerHTML = `
                <div style="background: #D4EDDA; border: 1px solid #C3E6CB; padding: 10px; border-radius: 4px; color: #155724;">
                    ✅ No alerts - Conditions are normal. Try selecting a scenario above.
                </div>
            `;
        }
        
        console.log('Test result:', result);
    } catch (e) {
        console.error(e);
        alert('Error testing alerts: ' + e.message);
    } finally {
        btn.innerText = originalText;
    }
}

// Trigger payout in app
async function triggerPayout() {
    const workerId = document.getElementById('worker-select').value;
    const alerts = window.currentAlerts || [];
    
    if (alerts.length === 0) {
        alert('No alerts to trigger');
        return;
    }
    
    try {
        const response = await fetch('/api/trigger-payout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                worker_id: workerId,
                alert_type: alerts[0].typeLabel,
                lat: document.getElementById('sim_lat').value,
                lon: document.getElementById('sim_lon').value
            })
        });
        
        const result = await response.json();
        
        document.getElementById('test-result').innerHTML = `
            <div style="background: #D4EDDA; border: 1px solid #C3E6CB; padding: 10px; border-radius: 4px; color: #155724;">
                <strong>✅ Payout Triggered!</strong><br>
                ${result.message || 'Check the Flutter app for updated payout'}
            </div>
        `;
        
        console.log('Trigger result:', result);
    } catch (e) {
        console.error(e);
        alert('Error triggering payout: ' + e.message);
    }
}
