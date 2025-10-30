const API_BASE_URL = 'http://127.0.0.1:5000'; // Your Flask backend URL

// ========================
// Utility Functions
// ========================

// Function to store data in local storage
function setSessionData(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
}

// Function to retrieve data from local storage
function getSessionData(key) {
    const data = localStorage.getItem(key);
    return data ? JSON.parse(data) : null;
}

// Function to remove data from local storage
function removeSessionData(key) {
    localStorage.removeItem(key);
}

// Function to show messages (success/error)
function showMessage(elementId, message, type) {
    const element = document.getElementById(elementId);
    if (element) {
        element.textContent = message;
        element.className = `message ${type}`;
        element.style.display = 'block';
        setTimeout(() => {
            element.style.display = 'none';
        }, 5000); // Hide after 5 seconds
    }
}

// ========================
// Reusable Components
// ========================

// Render Header
function renderHeader(showLogoutButton = true) {
    const headerElement = document.getElementById('main-header');
    if (headerElement) {
        headerElement.innerHTML = `
            <div class="container">
                <h1><a href="index.html">Feedback System</a></h1>
                <nav>
                    <ul>
                        <li><a href="index.html">Home</a></li>
                        ${getSessionData('student_id') ? `
                            <li><a href="student_dashboard.html">Student Dashboard</a></li>
                        ` : ''}
                        ${getSessionData('admin_id') ? `
                            <li><a href="admin_dashboard.html">Admin Dashboard</a></li>
                        ` : ''}
                        ${showLogoutButton && (getSessionData('student_id') || getSessionData('admin_id')) ? `
                            <li><a href="#" id="logout-button">Logout</a></li>
                        ` : ''}
                    </ul>
                </nav>
            </div>
        `;

        if (showLogoutButton) {
            const logoutButton = document.getElementById('logout-button');
            if (logoutButton) {
                logoutButton.addEventListener('click', (e) => {
                    e.preventDefault();
                    removeSessionData('student_id');
                    removeSessionData('admin_id');
                    alert('Logged out successfully!');
                    window.location.href = 'index.html';
                });
            }
        }
    }
}

// Render Footer
function renderFooter() {
    const footerElement = document.getElementById('main-footer');
    if (footerElement) {
        footerElement.innerHTML = `
            <div class="container">
                <p>&copy; ${new Date().getFullYear()} Faculty Feedback System. All rights reserved.</p>
            </div>
        `;
    }
}

// ========================
// API Call Utility
// ========================

async function apiCall(endpoint, method = 'GET', data = null) {
    const options = {
        method: method,
        headers: {
            'Content-Type': 'application/json',
            // 'Authorization': `Bearer ${getSessionData('token')}` // If you implement JWT tokens
        },
    };

    if (data) {
        options.body = JSON.stringify(data);
    }

    try {
        const response = await fetch(`${API_BASE_URL}${endpoint}`, options);
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.message || `HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error('API Call Error:', error);
        throw error; // Re-throw to be handled by specific page logic
    }
}

// ========================
// Form Validation Example (can be expanded)
// ========================
function validateForm(formId, rules) {
    const form = document.getElementById(formId);
    if (!form) return true; // No form to validate

    let isValid = true;
    const errors = [];

    for (const fieldName in rules) {
        const input = form.elements[fieldName];
        const fieldRules = rules[fieldName];

        if (!input) continue;

        if (fieldRules.required && !input.value.trim()) {
            isValid = false;
            errors.push(`${fieldRules.label || fieldName} is required.`);
        }
        // Add more validation rules (e.g., email format, min/max length, number range)
        if (fieldRules.type === 'email' && input.value.trim() && !/\S+@\S+\.\S+/.test(input.value)) {
            isValid = false;
            errors.push(`${fieldRules.label || fieldName} must be a valid email address.`);
        }
        if (fieldRules.type === 'number' && input.value.trim()) {
            const numValue = parseFloat(input.value);
            if (isNaN(numValue)) {
                isValid = false;
                errors.push(`${fieldRules.label || fieldName} must be a number.`);
            } else {
                if (fieldRules.min !== undefined && numValue < fieldRules.min) {
                    isValid = false;
                    errors.push(`${fieldRules.label || fieldName} must be at least ${fieldRules.min}.`);
                }
                if (fieldRules.max !== undefined && numValue > fieldRules.max) {
                    isValid = false;
                    errors.push(`${fieldRules.label || fieldName} must be at most ${fieldRules.max}.`);
                }
            }
        }
        // Password confirmation
        if (fieldRules.confirmWith && input.value !== form.elements[fieldRules.confirmWith].value) {
            isValid = false;
            errors.push(`${fieldRules.label || fieldName} does not match.`);
        }
    }

    return { isValid, errors };
}

// Global initialization for header/footer (for pages that don't override)
document.addEventListener('DOMContentLoaded', () => {
    // Only render logout if logged in
    renderHeader(true);
    renderFooter();
});

// ========================
// Placeholder Data Functions
// ========================

// Function to fetch placeholder data for dropdowns
async function fetchDropdownData() {
    // In a real scenario, you'd have API endpoints for these:
    // GET /api/branches
    // GET /api/years
    // GET /api/semesters
    // For now, returning hardcoded data
    return {
        branches: [
            { id: 1, name: 'Computer Science & Engineering', code: 'CSE' },
            { id: 2, name: 'Electronics & Communication', code: 'ECE' },
            { id: 3, name: 'Mechanical Engineering', code: 'ME' }
        ],
        years: [
            { id: 1, label: '1st Year' },
            { id: 2, label: '2nd Year' },
            { id: 3, label: '3rd Year' },
            { id: 4, label: '4th Year' }
        ],
        semesters: [
            { id: 1, label: 'Semester 1' },
            { id: 2, label: 'Semester 2' },
            { id: 3, label: 'Semester 3' },
            { id: 4, label: 'Semester 4' },
            { id: 5, label: 'Semester 5' },
            { id: 6, label: 'Semester 6' },
            { id: 7, label: 'Semester 7' },
            { id: 8, label: 'Semester 8' }
        ]
    };
}

// Function to populate a select element
function populateSelect(selectElement, data, valueKey, textKey, defaultOption = "Select...") {
    if (!selectElement) return;
    selectElement.innerHTML = `<option value="">${defaultOption}</option>`;
    data.forEach(item => {
        const option = document.createElement('option');
        option.value = item[valueKey];
        option.textContent = item[textKey];
        selectElement.appendChild(option);
    });
}

// Utility to check if a user is logged in
function checkAuth(role = 'student') {
    const id = getSessionData(`${role}_id`);
    if (!id) {
        alert(`You need to be logged in as a ${role} to access this page.`);
        window.location.href = `${role}_login.html`;
        return false;
    }
    return true;
}