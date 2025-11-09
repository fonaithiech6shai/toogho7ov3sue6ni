# Production Monitoring Guide for 1C Integration

This guide provides practical instructions for monitoring the enhanced 1C integration logging in production.

## Quick Start

### 1. Locating Log Files

The application logs are typically stored in:
- `/srv/log/rozarioflowers.ru.production.log`
- `/var/log/nginx/` (for web server logs)
- Application-specific log directory as configured in `config/boot.rb`

### 2. Real-time Monitoring

```bash
# Monitor 1C integration activity
tail -f /srv/log/rozarioflowers.ru.production.log | grep "\[TRANSACTION\|\[ITEM"

# Monitor only errors
tail -f /srv/log/rozarioflowers.ru.production.log | grep "❌"

# Monitor specific product issues
tail -f /srv/log/rozarioflowers.ru.production.log | grep "c7f2cd68-7c2a-40a1-90f6-ce58c196152f"
```

### 3. Daily Analysis

```bash
# Extract today's 1C logs
grep "$(date '+%Y-%m-%d')" /srv/log/rozarioflowers.ru.production.log | grep "\[TRANSACTION\|\[ITEM" > /tmp/1c_today.log

# Run analysis
cd /path/to/application
ruby -e "
  require './analyze_1c_logs.rb'
  analyzer = LogAnalyzer.new
  analyzer.analyze_log_content(File.read('/tmp/1c_today.log'))
  puts analyzer.generate_report
"
```

## Monitoring Checklist

### Daily Tasks

- [ ] Check transaction success rates (target: >90%)
- [ ] Review error patterns for new issues
- [ ] Identify repeatedly failing products
- [ ] Monitor thread conflicts
- [ ] Check for unusual processing volumes

### Weekly Tasks

- [ ] Analyze trends in error rates
- [ ] Review problematic product patterns
- [ ] Check for performance degradation
- [ ] Validate duplicate handling effectiveness
- [ ] Archive old log analysis reports

### Alert Conditions

1. **High Error Rate**: >20% transaction failures
2. **Repeated Failures**: Same product failing >5 times
3. **Thread Conflicts**: >10 conflicts per hour
4. **Zero Processing**: No 1C activity for >2 hours during business hours
5. **Transaction Failures**: Complete transaction rollbacks

## Common Log Patterns

### Normal Operation
```
[TRANSACTION START] Обработка 15 товаров от 1С
[ITEM 1/15] 1С ID: abc123, Title: '...'
[ITEM 1] ✓ Product created successfully
...
[TRANSACTION SUCCESS] Обработано: 15, Создано: 12, Обновлено: 3, Ошибок: 0
```

### Problems to Watch
```
# Validation errors
[ITEM X] ❌ PRODUCT SAVE FAILED for 1С ID: ...
[ITEM X] ❌ Product validation errors: ...

# Duplicate issues (normal but worth monitoring frequency)
[ITEM X] ⚠️ WARNING: Найдено X товаров с таким же slug

# Thread conflicts
Thread mutex conflict detected during processing

# Transaction failures
[TRANSACTION ERROR] Ошибка во время транзакции
```

## Automated Monitoring Scripts

### 1. Error Rate Monitor

```bash
#!/bin/bash
# File: monitor_1c_errors.sh

LOG_FILE="/srv/log/rozarioflowers.ru.production.log"
DATE=$(date '+%Y-%m-%d')
TMP_DIR="/tmp"

# Extract today's 1C logs
grep "$DATE" "$LOG_FILE" | grep "\[TRANSACTION\|\[ITEM" > "$TMP_DIR/1c_today.log"

# Count transactions and errors
TOTAL_TRANSACTIONS=$(grep -c "\[TRANSACTION START\]" "$TMP_DIR/1c_today.log")
FAILED_ITEMS=$(grep -c "❌.*FAILED" "$TMP_DIR/1c_today.log")

if [ "$TOTAL_TRANSACTIONS" -gt 0 ]; then
    ERROR_RATE=$(( FAILED_ITEMS * 100 / TOTAL_TRANSACTIONS ))
    
    echo "1C Integration Status - $DATE"
    echo "Transactions: $TOTAL_TRANSACTIONS"
    echo "Failed items: $FAILED_ITEMS"
    echo "Error rate: $ERROR_RATE%"
    
    if [ "$ERROR_RATE" -gt 20 ]; then
        echo "WARNING: High error rate detected!"
        # Add notification logic here
    fi
else
    echo "WARNING: No 1C transactions found today!"
fi
```

### 2. Problem Product Tracker

```bash
#!/bin/bash
# File: track_problem_products.sh

LOG_FILE="/srv/log/rozarioflowers.ru.production.log"
OUTPUT_FILE="/tmp/problem_products_$(date '+%Y%m%d').txt"

# Find products with repeated failures
grep "❌ PRODUCT SAVE FAILED for 1С ID:" "$LOG_FILE" | \
  grep -o "1С ID: [^,]*" | \
  sort | uniq -c | sort -nr > "$OUTPUT_FILE"

echo "Problem products (failure count):"
head -10 "$OUTPUT_FILE"

# Alert if any product has >5 failures
if awk '$1 > 5' "$OUTPUT_FILE" | grep -q .; then
    echo "ALERT: Products with >5 failures found!"
    awk '$1 > 5' "$OUTPUT_FILE"
fi
```

### 3. Daily Report Generator

```ruby
#!/usr/bin/env ruby
# File: daily_1c_report.rb

require_relative 'analyze_1c_logs.rb'

log_file = ARGV[0] || '/srv/log/rozarioflowers.ru.production.log'
date = Date.today.strftime('%Y-%m-%d')

# Extract today's logs
today_logs = File.readlines(log_file)
  .select { |line| line.include?(date) }
  .select { |line| line.match(/\[TRANSACTION|\[ITEM/) }
  .join("\n")

if today_logs.empty?
  puts "No 1C integration activity found for #{date}"
  exit 1
end

# Analyze logs
analyzer = LogAnalyzer.new
analyzer.analyze_log_content(today_logs)

# Generate report
report = analyzer.generate_report

report_file = "/tmp/1c_report_#{date.gsub('-', '')}.txt"
File.write(report_file, report)

puts "1C Integration Report for #{date}"
puts "=" * 50
puts report
puts "\nFull report saved to: #{report_file}"

# Email or slack notification logic can be added here
```

## Cron Job Setup

```bash
# Add to crontab (crontab -e)

# Check error rates every hour during business hours (9-18 UTC)
0 9-18 * * 1-5 /path/to/monitor_1c_errors.sh

# Generate daily report at 19:00
0 19 * * * /usr/bin/ruby /path/to/daily_1c_report.rb

# Weekly problem product summary (Mondays at 10:00)
0 10 * * 1 /path/to/track_problem_products.sh | mail -s "Weekly 1C Problem Products" admin@example.com
```

## Log Rotation and Maintenance

### Logrotate Configuration

```bash
# /etc/logrotate.d/rozario-1c
/srv/log/rozarioflowers.ru.*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        # Restart application if needed
        service nginx reload
    endscript
}
```

### Archive Analysis Reports

```bash
# Keep analysis reports for 90 days
find /tmp -name "1c_report_*.txt" -mtime +90 -delete
find /tmp -name "problem_products_*.txt" -mtime +90 -delete
```

## Troubleshooting Workflow

### When Alerts Fire

1. **High Error Rate Alert**:
   ```bash
   # Get immediate context
   tail -100 /srv/log/rozarioflowers.ru.production.log | grep -A 5 -B 5 "❌"
   
   # Generate detailed report
   ruby daily_1c_report.rb
   
   # Check for system issues
   df -h  # Disk space
   free -m  # Memory
   top  # CPU/processes
   ```

2. **Repeated Product Failures**:
   ```bash
   # Get full history of problematic product
   PRODUCT_ID="c7f2cd68-7c2a-40a1-90f6-ce58c196152f"
   grep "$PRODUCT_ID" /srv/log/rozarioflowers.ru.production.log | tail -20
   
   # Check database state
   # Connect to MySQL and check for conflicting records
   ```

3. **No Activity Alert**:
   ```bash
   # Check 1C system status
   curl -I "http://1c-server/api/status"
   
   # Check application status
   systemctl status nginx
   systemctl status passenger
   
   # Check network connectivity
   ping 1c-server-ip
   ```

## Performance Optimization

### Log Analysis Performance

- Use `grep` with specific patterns to reduce processing time
- Process logs in chunks for large files
- Consider using `awk` for complex filtering
- Archive old logs regularly

### Monitoring Resource Usage

```bash
# Monitor log file growth
watch "ls -lh /srv/log/rozarioflowers.ru.production.log"

# Monitor disk usage
df -h /srv/log/

# Monitor I/O during log analysis
iostat -x 1
```

## Emergency Procedures

### If 1C Integration Stops Working

1. Check recent error patterns
2. Verify 1C server connectivity
3. Check database connectivity
4. Review recent application changes
5. Check system resources
6. Restart application if needed

### If Logs Become Corrupted

1. Stop log analysis scripts
2. Backup current log files
3. Check filesystem integrity
4. Restart logging services
5. Monitor for proper log generation

## Support Contacts

- **Application Issues**: Development team
- **1C System Issues**: ERP administrator
- **Server Issues**: System administrator
- **Database Issues**: Database administrator

---

*This monitoring guide should be reviewed and updated regularly as the system evolves.*
