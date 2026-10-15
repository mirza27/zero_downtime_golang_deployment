package main

import (
	"log"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
)

func main() {
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGUSR1, syscall.SIGTERM)
	defer signal.Stop(signals)

	for {
		cmd := exec.Command("/app/server")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		if err := cmd.Start(); err != nil {
			log.Printf("start failed: %v", err)
		} else {
			done := make(chan error, 1)
			go func() {
				done <- cmd.Wait()
			}()

			select {
			case err := <-done:
				log.Printf("child exited: %v", err)

			case sig := <-signals:
				if sig == syscall.SIGTERM {
					_ = cmd.Process.Signal(syscall.SIGTERM)
					<-done
					return
				}

				_ = cmd.Process.Signal(syscall.SIGTERM)
				select {
				case <-done:
				}
			}
		}

		select {
		case sig := <-signals:
			if sig == syscall.SIGTERM {
				return
			}
		default:
		}
	}
}
