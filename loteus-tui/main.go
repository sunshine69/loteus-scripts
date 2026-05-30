package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/rivo/tview"
)

const (
	manageScript = "loteus-manage.py"
)

type AppState struct {
	app      *tview.Application
	mainList *tview.List
}

func main() {
	setupPath()
	app := tview.NewApplication()
	state := &AppState{
		app: app,
	}

	state.mainList = tview.NewList().ShowSecondaryText(true)
	setupMainMenu(state)

	if err := app.SetRoot(state.mainList, true).Run(); err != nil {
		fmt.Printf("Error running application: %v\n", err)
		os.Exit(1)
	}
}

func setupPath() {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	dir := filepath.Dir(exe)
	path := os.Getenv("PATH")
	// Prepend the directory of the executable to PATH for highest priority
	os.Setenv("PATH", dir+":"+path)
}

func setupMainMenu(s *AppState) {
	s.mainList.SetTitle(" Loteus Manager (TUI) ").SetBorder(true)

	// All commands now use the new integrated runner instead of xterm
	s.mainList.AddItem("Install Loteus", "Run installation wizard to install on a disk/partition.", 'i', func() { showInstallDialog(s) })
	s.mainList.AddItem("Update System", "Runs loteus-manage.py do_update", 'u', func() { runInSystemTerminal(s, manageScript+" do_update") })
	s.mainList.AddItem("Save Config", "Saves current configuration", 'c', func() { runInSystemTerminal(s, manageScript+" save_config") })
	s.mainList.AddItem("Resize USB Root", "Resizes the USB root partition", 'r', func() { runInSystemTerminal(s, manageScript+" resize_usb_root") })
	s.mainList.AddItem("Create Change Image", "Creates a persistent change image container (prompts for size)", 'm', func() { runCreateChangeImage(s) })
	s.mainList.AddItem("Update Tools", "Updates system tools", 't', func() { runInSystemTerminal(s, manageScript+" update_tools") })
	s.mainList.AddItem("Exit", "Quit the application", 'q', func() { s.app.Stop() })
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func findTerminal() string {
	// Priority list of common Linux terminal emulators
	candidates := []string{
		"x-terminal-emulator", // Debian/Ubuntu default symlink
		"gnome-terminal",
		"konsole",
		"xfce4-terminal",
		"terminator",
		"lxterminal",
		"xterm", // Last resort fallback
	}

	for _, term := range candidates {
		if _, err := exec.LookPath(term); err == nil {
			return term
		}
	}
	return ""
}

// runInSystemTerminal auto-detects a terminal emulator and runs the command inside it.
func runInSystemTerminal(s *AppState, fullCmd string) {
	// terminal := findTerminal()
	terminal := ""
	if terminal != "" && os.Getenv("DISPLAY") != "" {
		// Terminal found and DISPLAY is set: spawn in new terminal window (forked, no suspension needed)
		go func() {
			exec.Command(terminal, "-e", "bash", "-c", fullCmd).Run()
		}()
	} else {
		// No DISPLAY or no terminal found: suspend tview and run directly in current terminal
		// if os.Getenv("DISPLAY") == "" {
		// 	fmt.Println("Warning: No X11 display found (DISPLAY not set). Running command directly.")
		// } else if terminal == "" {
		// 	fmt.Println("Warning: No compatible terminal emulator found. Running command directly.")
		// }

		s.app.Suspend(func() {
			cmd := exec.Command("bash", "-c", fullCmd)
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr

			// 2. Run the command and wait for it to completely finish
			_ = cmd.Run()
			fmt.Print("Press 'Enter' to continue...")
			bufio.NewReader(os.Stdin).ReadBytes('\n')
		})
		s.app.Sync() // Force tview to rebuild and clear screen garbage
	}
}

func showInstallDialog(s *AppState) {
	flex := tview.NewFlex().SetDirection(tview.FlexRow)

	// 1. Info Box (TextView) - Displays partition information
	infoBox := tview.NewTextView()
	infoBox.SetDynamicColors(true)
	infoBox.SetBorder(true)
	infoBox.SetTitle(" Disk Information ")
	infoBox.SetText("[yellow]Loading disk information...[white]")

	// 2. Log View (TextView) - Captures the installation process output
	logView := tview.NewTextView()
	logView.SetDynamicColors(true)
	logView.SetScrollable(true)
	logView.SetChangedFunc(func() { s.app.Draw() })
	logView.SetBorder(true)
	logView.SetTitle(" Installation Log ")

	// 3. Form (Form) - Collects input and provides management/action buttons
	form := tview.NewForm()
	form.SetBorder(true)
	form.SetTitle(" Install Wizard ")
	var deviceName string

	// Corrected callback signature for AddInputField: func(text string, lastChar rune) bool
	form.AddInputField("Device Name (e.g., /dev/sdb): ", "", 30, func(text string, _ rune) bool {
		deviceName = text
		return true
	}, nil)

	// --- Partition Management Button Logic ---
	if commandExists("gparted") {
		form.AddButton("Open GParted (GUI)", func() {
			go func() {
				_ = exec.Command("gparted").Run()
				refreshDiskInfo(s, infoBox)
			}()
		})
	} else if commandExists("gdisk") {
		form.AddButton("Open GDisk (Interactive CLI)", func() {
			runInSystemTerminal(s, "gdisk")
			refreshDiskInfo(s, infoBox)
		})
	}

	form.AddButton("Next / Install", func() {
		if deviceName == "" {
			return
		}
		runInstallProcess(s, deviceName)
	})

	form.AddButton("Cancel/Back", func() {
		s.app.SetRoot(s.mainList, true)
	})

	// Layout construction: Info (top), Form (middle), Log (bottom)
	flex.AddItem(infoBox, 0, 5, false)
	flex.AddItem(form, 0, 2, false)
	// flex.AddItem(logView, 0, 3, false)

	s.app.SetRoot(flex, true)
	s.app.SetFocus(form)

	// Background fetcher for disk info
	go func() {
		data := getDiskInfoData()
		s.app.QueueUpdateDraw(func() { infoBox.SetText(data) })
	}()
}

// runIntegratedCommand replaces xterm functionality by running commands in the same terminal context (TUI).
func runIntegratedCommand(s *AppState, fullCmd string) {
	flex := tview.NewFlex().SetDirection(tview.FlexRow)

	titleView := tview.NewTextView()
	titleView.SetDynamicColors(true)
	titleView.SetTextAlign(tview.AlignCenter)
	titleView.SetBorder(true)
	titleView.SetTitle(" Running Command ")
	titleView.SetText(fmt.Sprintf("[green]Executing:[white] %s", fullCmd))

	logView := tview.NewTextView()
	logView.SetDynamicColors(true)
	logView.SetScrollable(true)
	logView.SetChangedFunc(func() { s.app.Draw() })
	logView.SetBorder(true)
	logView.SetTitle(" Output ")

	statusText := tview.NewTextView()
	statusText.SetDynamicColors(true)
	statusText.SetTextAlign(tview.AlignCenter)
	statusText.SetBorder(true)
	statusText.SetTitle(" Status ")
	statusText.SetText("[yellow]Running...[white]")

	flex.AddItem(titleView, 0, 1, false)
	flex.AddItem(logView, 0, 3, false)
	flex.AddItem(statusText, 0, 1, false)

	s.app.SetRoot(flex, true)

	go func() {
		cmd := exec.Command("bash", "-c", fullCmd)
		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		err := cmd.Start()
		if err != nil {
			s.app.QueueUpdateDraw(func() {
				statusText.SetText("[red]Failed to start command[white]")
				logView.SetText(fmt.Sprintf("[red]%v[white]", err))
			})
			time.Sleep(3 * time.Second)
			s.app.SetRoot(s.mainList, true)
			return
		}

		streamer := func(r io.Reader) {
			buf := make([]byte, 1024)
			for {
				n, err := r.Read(buf)
				if n > 0 {
					s.app.QueueUpdateDraw(func() { logView.Write(buf[:n]) })
				}
				if err != nil {
					break
				}
			}
		}

		go streamer(stdout)
		go streamer(stderr)

		cmd.Wait()

		// Completion Phase
		s.app.QueueUpdateDraw(func() {
			statusText.SetText("[green]Finished! Returning to menu in 3 seconds...[white]")
		})
		time.Sleep(3 * time.Second)
		s.app.SetRoot(s.mainList, true)
	}()
}

// runInSystemTerminalWithConfirmAndEfibootmgr runs the install with confirmation and shows efibootmgr output after
func runInSystemTerminalWithConfirmAndEfibootmgr(s *AppState, device string) {
	installCmd := fmt.Sprintf(`echo "Review the command and type YES and hit enter to continue. "; read c; if [ "$c" = "YES" ]; then /opt/bin/build-usb-hybrid-grub-boot.sh %s | tee /tmp/install.log; echo ""; echo "Install completed. Here is your current EFI boot order:"; echo ""; efibootmgr 2>&1 || true; echo ""; echo "Make sure the entry 'ubuntu' is the first one to boot if you want Ubuntu to boot first."; echo ""; echo "To set boot order run: sudo efibootmgr --bootorder XXXX,YYYY,ZZZZ"; echo ""; echo "--- Install command output ---"; cat /tmp/install.log; echo ""; echo "Hit enter to continue"; read ; else echo Aborted!; fi`, device)

	runInSystemTerminal(s, installCmd)
}

// refreshDiskInfo updates the infoBox with fresh disk information.
func refreshDiskInfo(s *AppState, infoBox *tview.TextView) {
	infoBox.SetText("[yellow]Loading disk information...[white]")
	go func() {
		data := getDiskInfoData()
		s.app.QueueUpdateDraw(func() { infoBox.SetText(data) })
	}()
}

// --- Helper functions from previous versions (Disk Info and Install Process) ---

func getDiskInfoData() string {
	cmd := exec.Command("bash", "-c", "lsblk --list --noheadings | grep -v memory | grep -v squashfs | grep -v 'loop' | grep -v 'zram' | grep -v 'crypto_LUKS' | grep -v 'EFI System' | grep -v 'BIOS boot partition'")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Sprintf("Error: %v\n%s", err, string(output))
	}

	mountPoint := "/"
	size := "unknown"

	return fmt.Sprintf(`%s

Click 'Open GParted' or 'Open GDisk' to create/resize partitions. After exiting,
click the 'Refresh Disk Info' button to update the display.

Then type the device name below. It can be a full disk, or just a single
partition.

CAREFULLY:
  - For any case the data in the full disk or the partition will be erased.
  - You cannot select the disk or partition that the current live system runs. They are mounted at %s with size %s`, string(output), mountPoint, size)
}

// runCreateChangeImage prompts for IMAGE_SIZE in terminal then runs create_change_image
func runCreateChangeImage(s *AppState) {
	runInSystemTerminal(s, fmt.Sprintf(
		"echo 'Enter the size of the container. Hit enter to choose default 1G. To create 5G container enter 5000. You should make it as large as your disk space allows it.'; read IMAGE_SIZE; [ -z \"$IMAGE_SIZE\" ] && IMAGE_SIZE=1024; export IMAGE_SIZE; %s create_change_image; echo 'Hit enter to close'; read _junk",
		manageScript))
}

func runInstallProcess(s *AppState, device string) {
	runInSystemTerminalWithConfirmAndEfibootmgr(s, device)
}
