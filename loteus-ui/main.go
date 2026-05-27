package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	fltk "github.com/pwiecz/go-fltk"
)

// Global variables for script directory and terminal emulator
var scriptDir string
var termEmu string

func findTerminal() {
	terminals := []string{
		"x-terminal-emulator", 
		"gnome-terminal", 
		"konsole", 
		"xfce4-terminal", 
		"terminator", 
		"alacritty", 
		"kitty", 
		"xterm",
	}

	for _, t := range terminals {
		if _, err := exec.LookPath(t); err == nil {
			termEmu = t
			return
		}
	}
    // Fallback to xterm if nothing found (though it's in the list)
	termEmu = "xterm" 
}

func setupEnvironment() error {
	// Determine script directory from environment or executable location
	scriptDir = os.Getenv("LOTEUS_SCRIPT_DIR")
	if scriptDir == "" {
		exe, _ := exec.LookPath(os.Args[0])
		if exe != "" {
			scriptDir = filepath.Dir(exe)
		} else {
			dir, err := os.Getwd()
			if err != nil {
				return fmt.Errorf("failed to get working directory: %v", err)
			}
			scriptDir = dir
		}
	}

    // Ensure scriptDir is an absolute path for reliability in PATH
    absScriptDir, err := filepath.Abs(scriptDir)
    if err != nil {
        return fmt.Errorf("failed to resolve absolute path: %v", err)
    }
    scriptDir = absScriptDir

	// Update PATH so that loteus scripts have highest priority
	currentPath := os.Getenv("PATH")
	newPath := fmt.Sprintf("%s:%s", scriptDir, currentPath)
	return os.Setenv("PATH", newPath)
}

func getDiskInfo() string {
	cmd := exec.Command("bash", "-c", "lsblk --list --noheadings | grep -v memory | grep -v squashfs | grep -v 'loop' | grep -v 'zram' | grep -v 'crypto_LUKS' | grep -v 'EFI System' | grep -v 'BIOS boot partition'")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Sprintf("Error: %v\n%s", err, string(output))
	}

	mountPoint := "/"
	size := "unknown"

	return fmt.Sprintf(`%s

Click the button 'Exec Gparted' to run the partition tool to create/resize
new partition to use. After exiting the disk info will be refreshed.

Then type the device name below. It can be a full disk, or just a single
partition.

CAREFULLY:
  - For any case the data in the full disk or the partition will be erased.
  - You cannot select the disk or partition that the current live system runs. They are mounted at %s with size %s`, string(output), mountPoint, size)
}

func runCommandSilent(cmdStr string) (string, int, error) {
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	return string(output), cmd.ProcessState.ExitCode(), err
}

// Helper to run command in a detected terminal emulator for long tasks
func runInTerminal(cmdStr string) {
    // Most terminals accept -e followed by the command. 
	fullCmd := fmt.Sprintf("%s -e bash -c '%s; echo \"Hit enter to close\"; read _'", termEmu, cmdStr)
	exec.Command("bash", "-c", fullCmd).Run()
}

// NewInstallDialogFixed uses manual positioning (proven working in original code) 
// but adds tooltips and cleaner logic for improved UX.
func NewInstallDialogFixed() {
	w := fltk.NewWindow(800, 650, "Loteus Installation Wizard")
    textBuf := fltk.NewTextBuffer()

    // Disk Info Area (Top)
	dispArea := fltk.NewTextEditor(10, 30, 780, 320)
	dispArea.SetBuffer(textBuf)
	textBuf.SetText(getDiskInfo())

    // Input Area (Middle)
	deviceInput := fltk.NewInput(160, 360, 400, 25, "Target Device:")

	// Buttons (Bottom Row/Area)
	cancelButton := fltk.NewButton(580, 360, 100, 25, "Cancel")
    
    var partitionBtnLabel string
    var isGparted bool
    if _, err := exec.LookPath("gparted"); err == nil {
        partitionBtnLabel = "Exec GParted"
        isGparted = true
    } else {
        partitionBtnLabel = "Exec Gdisk"
        isGparted = false
    }

	partitionButton := fltk.NewButton(10, 410, 150, 30, partitionBtnLabel)
	nextButton := fltk.NewButton(170, 410, 100, 30, "Next")

    // Add tooltips for better UX (parity with original glade)
    cancelButton.SetTooltip("Close the installation window.")
    partitionButton.SetTooltip(fmt.Sprintf("Open %s to manage partitions before installing.", partitionBtnLabel))
    nextButton.SetTooltip("Proceed with the installation using the target device specified above.")

	cancelButton.SetCallback(func() { w.Hide() })

	partitionButton.SetCallback(func() {
        if isGparted {
            runCommandSilent("gparted")
        } else {
            // If gdisk, run it through the terminal as requested
            runInTerminal("gdisk")
        }
		textBuf.SetText(getDiskInfo())
	})

	nextButton.SetCallback(func() {
		device := deviceInput.Value() 
		if device == "" {
			textBuf.SetText("[red]ERROR: Device path is required[reset]\n")
			return
		}

        // Removed hardcoded /opt/bin prefix since it's now in PATH via setupEnvironment()
		cmdStr := fmt.Sprintf(`%s -e bash -c 'echo will run build-usb-hybrid-grub-boot.sh %s; echo "Review the command and type YES and hit enter to continue."; read c; if [ "$c" = "YES" ]; then build-usb-hybrid-grub-boot.sh %s | tee /tmp/install.log; echo "Review the result and Hit enter to continue"; read ; else echo Aborted!; fi'`, termEmu, device, device)

		_, exitCode, err := runCommandSilent(cmdStr)
		status := "SUCCESS"
		if err != nil || exitCode != 0 {
			status = "FAIL"
		}

		logContent := ""
		if data, err := os.ReadFile("/tmp/install.log"); err == nil {
			logContent = string(data)
		}

		msg := fmt.Sprintf("Install completed with status %s.\n\nCommand output:\n%s", status, logContent)

		if efibootOutput, _, _ := runCommandSilent("efibootmgr"); efibootOutput != "" {
			msg += fmt.Sprintf("\n\nCurrent EFI Boot Order:\n%s\n\nMake sure the entry 'ubuntu' is the first one to boot if you want Ubuntu to boot first.", efibootOutput)
		}

		textBuf.SetText(msg)
	})

	w.End()
	w.Show()
}

func main() {
    findTerminal() 
    if err := setupEnvironment(); err != nil {
        fmt.Fprintf(os.Stderr, "Initialization Error: %v\n", err)
        os.Exit(1)
    }

	mainWin := fltk.NewWindow(320, 580, "Loteus System Manager")

    // Manual positioning for stability and compilation ease in current binding environment
	y := 60
	btnSpacing := 50

	createBtn := func(label string, tooltip string, callback func()) {
		btn := fltk.NewButton(15, y, 290, 45, label)
        y += btnSpacing
        btn.SetTooltip(tooltip)
		btn.SetCallback(callback)
	}

    // Button Tooltips ported from the original .glade file for professional UX
	createBtn("Install Loteus", "Install the current running system to hard disk or USB disk.", func() { 
        NewInstallDialogFixed() 
    })

	createBtn("Update System", "Run update the current running system. You need to reboot after that.", func() {
		runInTerminal("loteus-manage.py do_update")
	})

	createBtn("Save Config", "The local config such as wifi, network or user accounts will be saved", func() {
		runInTerminal("loteus-manage.py save_config")
	})

	createBtn("System Upgrade", "Download and replace the current OS images with selected version.", func() {
		runInTerminal("echo 'The feature is currently not implemented yet.';")
	})

    createBtn("Resize USB Disk", "Resize the last partition of USB live to maximize space usage.", func() {
		runInTerminal("loteus-manage.py resize_usb_root")
	})

    // For Image creation, using terminal emulator for user prompt via shell 'read' 
	createBtn("Encrypted Change Image", "Create a disk container and encrypt it.", func() {
        // Removed hardcoded scriptDir path in the command string because loteus-manage.py is now in PATH
		cmdStr := fmt.Sprintf("%s -e bash -c \"echo 'Enter the size of the container (in MB). Default 1024.'; read IMAGE_SIZE; [ -z \\\"$IMAGE_SIZE\\\" ] && IMAGE_SIZE=1024; export IMAGE_SIZE; loteus-manage.py create_change_image\"", termEmu)
		runInTerminal(cmdStr)
	})

	createBtn("Update Tools", "Run to update the loteus management tools.", func() {
		runInTerminal("loteus-manage.py update_tools")
	})

	createBtn("Help", "Open help page in browser.", func() {
		runInTerminal("echo 'Feature not implemented.';")
	})

	mainWin.End()
	mainWin.Show()

	if err := fltk.Run(); err != 0 {
		fmt.Fprintf(os.Stderr, "FLTK error: %v\n", err)
		os.Exit(1)
	}
}
