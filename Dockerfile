# Use a base image with Python
FROM python:3.11

# Set the working directory
WORKDIR /app

# Copy the setup script and make it executable
COPY setup_dolphin_web_interface.sh /app/setup_dolphin_web_interface.sh
RUN chmod +x /app/setup_dolphin_web_interface.sh

# Copy the web interface directory
COPY dolphin_web_interface /app/dolphin_web_interface

# Install dependencies
RUN /app/setup_dolphin_web_interface.sh

# Expose the Flask app port
EXPOSE 8080

# Command to run the Flask app
CMD ["python", "/app/dolphin_web_interface/app.py"]
