const API_ENDPOINT = "REPLACE_ME_API_URL";

const imageInput = document.getElementById('imageInput');
const uploadBtn = document.getElementById('uploadBtn');
const analyzedImage = document.getElementById('analyzedImage');
const labelsList = document.getElementById('labelsList');
const confidenceBar = document.getElementById('confidenceBar');
const confidenceText = document.getElementById('confidenceText');
const primaryLabel = document.getElementById('primaryLabel');
const statusBadge = document.getElementById('statusBadge');

// 1. Open File Picker
uploadBtn.addEventListener('click', () => imageInput.click());

// 2. Process Upload
imageInput.addEventListener('change', async () => {
    const file = imageInput.files[0];
    if (!file) return;

    // Preview
    const reader = new FileReader();
    reader.onload = (e) => analyzedImage.src = e.target.result;
    reader.readAsDataURL(file);

    primaryLabel.innerText = "Analyzing...";
    statusBadge.classList.add('hidden');

    try {
        const base64Image = await toBase64(file);
        
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                image_name: file.name,
                image_data: base64Image
            })
        });

        const data = await response.json();
        renderResults(data);
        
    } catch (error) {
        console.error("API Error:", error);
        primaryLabel.innerText = "Connection Error";
    }
});

function renderResults(data) {
    statusBadge.classList.remove('hidden');
    
    // Set Primary Result
    const top = data.labels[0];
    primaryLabel.innerText = top.Name;
    confidenceText.innerText = `${Math.round(top.Confidence)}%`;
    confidenceBar.style.width = `${top.Confidence}%`;

    // Render List
    labelsList.innerHTML = data.labels.map(l => `
        <div class="flex items-center justify-between p-2 rounded-lg bg-slate-50 dark:bg-slate-800/50">
            <span class="text-xs font-medium">${l.Name}</span>
            <span class="text-[10px] font-bold text-primary">${Math.round(l.Confidence)}%</span>
        </div>
    `).join('');
}

const toBase64 = file => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = () => resolve(reader.result.split(',')[1]);
    reader.onerror = error => reject(error);
});