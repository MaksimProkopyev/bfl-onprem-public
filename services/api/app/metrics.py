from prometheus_client import Counter, Histogram
http_latency = Histogram('bfl_autopilot_http_latency_seconds','HTTP request latency',['path','method','code'])
login_requests = Counter('bfl_autopilot_login_requests_total','Login requests',['result','code'])
rate_limit_hits = Counter('bfl_autopilot_rate_limit_hits_total','Rate limit hits')
auth_invalid_token = Counter('bfl_autopilot_auth_invalid_token_total','Invalid auth tokens')
