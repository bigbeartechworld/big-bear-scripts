// Test file with legitimate emoji usage
// This simulates a React component with UI emojis
// Should PASS with --exclude-emojis flag

const TemplateSelector = () => {
  return (
    <div className="template-selector">
      <Badge variant="info">
        🏷️ {brandCount} brands
      </Badge>
      <Badge variant="success">
        🏪 {storeCount} stores
      </Badge>
      <Badge variant="primary">
        ✅ {completedCount} completed
      </Badge>
      <Badge variant="warning">
        ⚠️ {warningCount} warnings
      </Badge>
      <Badge variant="danger">
        ❌ {errorCount} errors
      </Badge>
    </div>
  );
};

// Emojis used in status messages
const statusMessages = {
  success: "✅ Operation completed successfully",
  error: "❌ An error occurred",
  warning: "⚠️ Please review the following",
  info: "ℹ️ For your information",
  loading: "⏳ Loading data..."
};

// Feature list with emojis
const features = [
  "🚀 Fast performance",
  "🔒 Secure by default",
  "📱 Mobile responsive",
  "🎨 Beautiful UI",
  "⚡ Lightning fast"
];

export { TemplateSelector, statusMessages, features };
