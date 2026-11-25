# Key PowerShell Concepts Highlighted

• Pipelines & Streaming (|): Instead of loading everything into temporary variables step-by-step, PowerShell passes objects from Get-Content -> ForEach-Object -> Where-Object in a continuous stream.
• Array Subexpression @(...): Wrapping a pipeline in @(...) avoids a classic PowerShell gotcha where a single matching line returns a plain String (whose .Count is the number of characters) instead of a 1-item Array (whose .Count is 1).
• Scopes ($script: and global:): Explains why scope prefixes are necessary so helper functions (n and q) can communicate back to the main script loop.
• try / finally: Demonstrates how PowerShell ensures your terminal environment is always restored to its original state when the script finishes.
Would you like me to also provide the annotated version of the Python script (file-extension-filter.py), or generate a beginner-friendly README.md for your GitHub repository?
