#!/bin/bash

PORT=3000
PID=$(lsof -ti:$PORT)

if [ -n "$PID" ]; then
  echo "Port $PORT belegt von PID $PID – wird beendet..."
  kill -9 $PID
  sleep 1
fi

echo "Starte Backend..."
npm run start:dev
