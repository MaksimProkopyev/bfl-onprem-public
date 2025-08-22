import signal
from services.common.autopilot import QueueBackend, Runner

def main():
    q = QueueBackend()
    r = Runner(q)
    def _sigint(*_): r.stop()
    signal.signal(signal.SIGINT, _sigint)
    signal.signal(signal.SIGTERM, _sigint)
    r.run_forever()

if __name__ == "__main__":
    main()
