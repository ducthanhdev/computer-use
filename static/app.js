// DeskPulse Client App
let currentTab = 'overview';
let procSort = 'cpu';
let deferredPrompt = null;
let pollTimer = null;
let procTimer = null;
let failCount = 0;

// Elements
const elStatusBadge = document.getElementById('status-badge');
const elStatusText = document.getElementById('status-text');
const elPingVal = document.getElementById('ping-val');
const elHostName = document.getElementById('host-name');
const elOsName = document.getElementById('os-name');
const elUptimeVal = document.getElementById('uptime-val');
const elBatteryPill = document.getElementById('battery-pill');
const elBatteryVal = document.getElementById('battery-val');
const elInstallBanner = document.getElementById('install-banner');
const elInstallBtn = document.getElementById('install-btn');

// CPU elements
const elCpuVal = document.getElementById('cpu-val');
const elCpuBar = document.getElementById('cpu-bar');
const elCpuCores = document.getElementById('cpu-cores');
const elCpuTemp = document.getElementById('cpu-temp');
const elCoreGrid = document.getElementById('core-grid');

// Memory & Disk elements
const elMemVal = document.getElementById('mem-val');
const elMemBar = document.getElementById('mem-bar');
const elMemSub = document.getElementById('mem-sub');
const elSwapSub = document.getElementById('swap-sub');
const elDiskContainer = document.getElementById('disk-container');

// Network elements
const elNetDown = document.getElementById('net-down');
const elNetUp = document.getElementById('net-up');
const elNetTotal = document.getElementById('net-total');

// Process elements
const elProcList = document.getElementById('proc-list');
const elSortCpu = document.getElementById('sort-cpu');
const elSortMem = document.getElementById('sort-mem');

// Toast
const elToast = document.getElementById('toast');

function showToast(msg) {
  elToast.textContent = msg;
  elToast.classList.add('show');
  setTimeout(() => elToast.classList.remove('show'), 2200);
}

// Service Worker Registration for PWA
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch((err) => {
      console.log('SW registration note:', err);
    });
  });
}

// PWA Install Prompt Listener
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
  if (elInstallBanner) {
    elInstallBanner.style.display = 'flex';
  }
});

if (elInstallBtn) {
  elInstallBtn.addEventListener('click', async () => {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      const choice = await deferredPrompt.userChoice;
      if (choice.outcome === 'accepted') {
        elInstallBanner.style.display = 'none';
        showToast('Đang cài đặt app vào điện thoại...');
      }
      deferredPrompt = null;
    }
  });
}

// Tab Switching
document.querySelectorAll('.tab-item').forEach((btn) => {
  btn.addEventListener('click', () => {
    const tab = btn.dataset.tab;
    if (tab === currentTab) return;

    document.querySelectorAll('.tab-item').forEach((b) => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach((c) => c.classList.remove('active'));

    btn.classList.add('active');
    const target = document.getElementById(`tab-${tab}`);
    if (target) target.classList.add('active');
    currentTab = tab;

    if (tab === 'processes') {
      fetchProcesses();
    }
  });
});

// Process Sort Toggle
if (elSortCpu && elSortMem) {
  elSortCpu.addEventListener('click', () => {
    procSort = 'cpu';
    elSortCpu.classList.add('active');
    elSortMem.classList.remove('active');
    fetchProcesses();
  });

  elSortMem.addEventListener('click', () => {
    procSort = 'mem';
    elSortMem.classList.add('active');
    elSortCpu.classList.remove('active');
    fetchProcesses();
  });
}

// Helper: Color by usage percentage
function getFillClass(percent) {
  if (percent >= 85) return 'progress-fill danger';
  if (percent >= 65) return 'progress-fill warn';
  return 'progress-fill';
}

// Fetch Status Loop
async function fetchStatus() {
  const startTime = Date.now();
  try {
    const res = await fetch('/api/status', { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    const latency = Date.now() - startTime;

    failCount = 0;
    elStatusBadge.className = 'status-badge';
    elStatusText.textContent = 'TRỰC TUYẾN';
    elPingVal.textContent = `${latency}ms`;

    // System info
    if (data.system) {
      elHostName.textContent = data.system.hostname;
      elOsName.textContent = data.system.os_name;
    }
    if (data.uptime) {
      elUptimeVal.textContent = `⏱ ${data.uptime.formatted}`;
    }

    // Battery
    if (data.battery && data.battery.has_battery) {
      elBatteryPill.style.display = 'inline-flex';
      const isCharging = data.battery.status.toLowerCase().includes('charge');
      elBatteryVal.textContent = `${data.battery.percent}%${isCharging ? ' ⚡' : ''}`;
    } else {
      elBatteryPill.style.display = 'none';
    }

    // CPU
    if (data.cpu) {
      const cpuPct = data.cpu.percent;
      elCpuVal.textContent = cpuPct.toFixed(1);
      elCpuBar.className = getFillClass(cpuPct);
      elCpuBar.style.width = `${Math.min(100, Math.max(0, cpuPct))}%`;
      elCpuCores.textContent = `${data.cpu.cores_count} cores`;

      if (data.cpu.temperature_c) {
        elCpuTemp.textContent = `${data.cpu.temperature_c}°C 🔥`;
        elCpuTemp.style.display = 'inline-block';
      } else {
        elCpuTemp.style.display = 'none';
      }

      // Per-core mini bars
      if (Array.isArray(data.cpu.cores) && data.cpu.cores.length > 0) {
        renderCoreBars(data.cpu.cores);
      }
    }

    // Memory
    if (data.memory) {
      const mem = data.memory;
      elMemVal.textContent = mem.percent.toFixed(1);
      elMemBar.className = getFillClass(mem.percent);
      elMemBar.style.width = `${Math.min(100, Math.max(0, mem.percent))}%`;
      elMemSub.textContent = `${(mem.used_mb / 1024).toFixed(1)} / ${(mem.total_mb / 1024).toFixed(1)} GB`;

      if (mem.swap_total_mb > 0) {
        elSwapSub.textContent = `Swap: ${(mem.swap_used_mb / 1024).toFixed(1)} / ${(mem.swap_total_mb / 1024).toFixed(1)} GB (${mem.swap_percent}%)`;
      }
    }

    // Disks
    if (Array.isArray(data.disks)) {
      renderDisks(data.disks);
    }

    // Network
    if (data.network) {
      const net = data.network;
      elNetDown.textContent = formatSpeed(net.download_kbps);
      elNetUp.textContent = formatSpeed(net.upload_kbps);
      elNetTotal.textContent = `Tổng: ↓${(net.total_rx_mb / 1024).toFixed(2)}GB  ↑${(net.total_tx_mb / 1024).toFixed(2)}GB`;
    }

  } catch (err) {
    failCount++;
    if (failCount >= 2) {
      elStatusBadge.className = 'status-badge disconnected';
      elStatusText.textContent = 'MẤT KẾT NỐI';
      elPingVal.textContent = '--';
    }
  }
}

function renderCoreBars(cores) {
  if (elCoreGrid.children.length !== cores.length) {
    elCoreGrid.innerHTML = '';
    cores.forEach((_, idx) => {
      const col = document.createElement('div');
      col.className = 'core-col';
      col.innerHTML = `
        <div class="core-bar-wrap">
          <div class="core-bar" id="cbar-${idx}" style="height: 0%"></div>
        </div>
        <span class="core-label">C${idx + 1}</span>
      `;
      elCoreGrid.appendChild(col);
    });
  }
  cores.forEach((pct, idx) => {
    const bar = document.getElementById(`cbar-${idx}`);
    if (bar) {
      bar.style.height = `${Math.min(100, Math.max(0, pct))}%`;
      if (pct >= 85) bar.style.backgroundColor = 'var(--accent-rose)';
      else if (pct >= 65) bar.style.backgroundColor = 'var(--accent-amber)';
      else bar.style.backgroundColor = 'var(--accent-cyan)';
    }
  });
}

function renderDisks(disks) {
  elDiskContainer.innerHTML = '';
  disks.forEach((disk) => {
    const div = document.createElement('div');
    div.style.marginBottom = '10px';
    div.innerHTML = `
      <div class="metric-row">
        <div>
          <span style="font-weight: 700; color: #f8fafc; font-size: 0.9rem;">${disk.mount}</span>
          <span class="metric-sub" style="margin-left: 6px;">${disk.used_gb} / ${disk.total_gb} GB</span>
        </div>
        <span style="font-weight: 700; font-size: 0.95rem; color: #f8fafc;">${disk.percent}%</span>
      </div>
      <div class="progress-track">
        <div class="${getFillClass(disk.percent)}" style="width: ${disk.percent}%"></div>
      </div>
    `;
    elDiskContainer.appendChild(div);
  });
}

function formatSpeed(kbps) {
  if (kbps >= 1024) {
    return `${(kbps / 1024).toFixed(1)} MB/s`;
  }
  return `${Math.round(kbps)} KB/s`;
}

// Fetch Processes
async function fetchProcesses() {
  try {
    const res = await fetch(`/api/processes?sort=${procSort}&limit=12`);
    if (!res.ok) return;
    const data = await res.json();
    const list = data.processes || [];

    elProcList.innerHTML = '';
    if (list.length === 0) {
      elProcList.innerHTML = '<div style="text-align: center; color: var(--text-muted); padding: 20px;">Không có dữ liệu tiến trình</div>';
      return;
    }

    list.forEach((p) => {
      const item = document.createElement('div');
      item.className = 'proc-item';
      item.innerHTML = `
        <div class="proc-info">
          <span class="proc-name">${escapeHtml(p.name)}</span>
          <span class="proc-pid">PID: ${p.pid} • ${p.user}</span>
        </div>
        <div class="proc-badges">
          <span class="proc-pill ${procSort === 'cpu' ? 'highlight' : ''}">${p.cpu}% CPU</span>
          <span class="proc-pill ${procSort === 'mem' ? 'highlight' : ''}">${p.mem}% RAM</span>
        </div>
      `;
      elProcList.appendChild(item);
    });
  } catch (err) {
    console.error('Fetch processes error:', err);
  }
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Remote Control Actions
async function sendAction(action, confirmMsg = null) {
  if (confirmMsg && !confirm(confirmMsg)) {
    return;
  }

  showToast('Đang gửi lệnh...');
  try {
    const res = await fetch('/api/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action })
    });
    const data = await res.json();
    if (data.success) {
      showToast(data.message || 'Thực hiện thành công!');
    } else {
      showToast(`Lỗi: ${data.error || 'Thao tác thất bại'}`);
    }
  } catch (err) {
    showToast('Lỗi gửi lệnh đến máy tính');
  }
}

// Bind Action Buttons
document.querySelectorAll('[data-action]').forEach((btn) => {
  btn.addEventListener('click', () => {
    const action = btn.dataset.action;
    const confirmText = btn.dataset.confirm || null;
    sendAction(action, confirmText);
  });
});

// Start Loops
fetchStatus();
pollTimer = setInterval(fetchStatus, 1000);
procTimer = setInterval(() => {
  if (currentTab === 'processes') {
    fetchProcesses();
  }
}, 3000);
