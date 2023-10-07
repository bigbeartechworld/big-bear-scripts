#!/bin/bash

# This script sends an email using the telnet command.
# The email details can be provided interactively or default values will be used.

# Set default values for the SMTP server details and email content.
DEFAULT_SMTP_SERVER="smtp.server.com"
DEFAULT_SMTP_PORT="1025"
DEFAULT_SENDER="sender@example.com"
DEFAULT_RECIPIENT="recipient@example.com"
DEFAULT_SUBJECT="Default HTML Email"
DEFAULT_MESSAGE="<html><body><h1>Hello, World!</h1><p>This is a default test message in <strong>HTML</strong>.</p></body></html>"

# Prompt the user to enter the SMTP server details and email content.
# If the user doesn't provide any input, default values will be used.

read -p "Enter SMTP Server [$DEFAULT_SMTP_SERVER]: " SMTP_SERVER
SMTP_SERVER="${SMTP_SERVER:-$DEFAULT_SMTP_SERVER}"

read -p "Enter SMTP Port [$DEFAULT_SMTP_PORT]: " SMTP_PORT
SMTP_PORT="${SMTP_PORT:-$DEFAULT_SMTP_PORT}"

read -p "Enter Sender Email [$DEFAULT_SENDER]: " SENDER
SENDER="${SENDER:-$DEFAULT_SENDER}"

read -p "Enter Recipient Email [$DEFAULT_RECIPIENT]: " RECIPIENT
RECIPIENT="${RECIPIENT:-$DEFAULT_RECIPIENT}"

read -p "Enter Email Subject [$DEFAULT_SUBJECT]: " SUBJECT
SUBJECT="${SUBJECT:-$DEFAULT_SUBJECT}"

read -p "Enter Message Body (HTML) [$DEFAULT_MESSAGE]: " MESSAGE
MESSAGE="${MESSAGE:-$DEFAULT_MESSAGE}"

# Send the email using the telnet command.
# This section creates a sequence of SMTP commands to be piped into the telnet command.
# Each command is followed by a sleep to ensure that the SMTP server has time to process it.

{
    sleep 2
    echo "EHLO localhost" # Start the SMTP handshake.
    sleep 2
    echo "MAIL FROM:<$SENDER>" # Specify the sender.
    sleep 2
    echo "RCPT TO:<$RECIPIENT>" # Specify the recipient.
    sleep 2
    echo "DATA" # Start the data section of the email.
    sleep 2
    echo "Subject: $SUBJECT" # Add the subject.
    echo "Content-Type: text/html; charset=utf-8" # Specify that the email content is HTML.
    echo "" # Empty line to separate headers from the body.
    echo "$MESSAGE" # Add the email body.
    echo "." # End the data section.
    sleep 2
    echo "QUIT" # Quit the SMTP session.
} | telnet $SMTP_SERVER $SMTP_PORT # Pipe the SMTP commands into the telnet command.
