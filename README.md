# Shift auto publisher
Automated publication of content to the Shift storage cluster

Actions:
1. Check status
2. Download
3. Encrypt (optionally)
4. Upload (+ pin)
5. Publish (if needed)
6. Generate and broadcast a pin transaction
7. Request at random peers (create cache)
8. Collectively pin at Phoenix

This script is designed to be executed as cron task. 
First make the script executable:
```chmod +x publish.sh```
Then add this to your crontab to run it every hour:
```1 * * * * sudo /home/user/auto-publish/publish.sh > /home/user/auto-publish/cron.log 2>&1```
