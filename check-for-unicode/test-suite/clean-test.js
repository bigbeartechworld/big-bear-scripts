// Clean JavaScript file with no dangerous Unicode characters
// This should pass the scanner without any issues

function authenticateUser(username, password) {
    if (username === "admin" && password === "secret123") {
        return {
            success: true,
            role: "administrator",
            permissions: ["read", "write", "delete"]
        };
    }
    return {
        success: false,
        message: "Invalid credentials"
    };
}

const config = {
    host: "localhost",
    port: 3000,
    database: "myapp",
    timeout: 5000
};

const users = [
    { id: 1, name: "John Doe", email: "john@example.com" },
    { id: 2, name: "Jane Smith", email: "jane@example.com" }
];

// Standard ASCII characters only
const message = "Hello, World!";
const numbers = [1, 2, 3, 4, 5];
const symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?";

export { authenticateUser, config, users, message };