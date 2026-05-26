package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	fltk "github.com/pwiecz/go-fltk"
)

// Global variables for script directory
var scriptDir string

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

// InstallDialog represents the install window - separate from main window
type InstallDialog struct {
	window        *fltk.Window
	deviceInput   *fltk.Input
	textDisplay   *fltk.TextBuffer
	cancelButton  *fltk.Button
	nextButton    *fltk.Button
	gpartedButton *fltk.Button
}

func NewInstallDialog() *InstallDialog {
	w := fltk.NewWindow(800, 600, "Install Loteus")

	// Create text buffer for disk info
	textBuf := fltk.NewTextBuffer()
	textDisplay := fltk.NewTextEditor(10, 10, 780, 300)
	textDisplay.SetLabel("Disk Info")
	textDisplay.SetBuffer(textBuf)

	// Device input with label (label is passed as text parameter)
	deviceInput := fltk.NewInput(160, 320, 400, 25, "Target Device:")

	// Buttons
	cancelButton := fltk.NewButton(580, 320, 100, 25, "Cancel")
	gpartedButton := fltk.NewButton(10, 360, 150, 25, "Exec GParted")
	nextButton := fltk.NewButton(170, 360, 100, 25, "Next")

	// Set callback functions
	cancelButton.SetCallback(func() {
		w.Hide()
	})

	gpartedButton.SetCallback(func() {
		runCommandSilent("gparted")
		textBuf.SetText(getDiskInfo())
	})

	nextButton.SetCallback(func() {
		device := deviceInput.Value()
		if device == "" {
			textBuf.SetText("[red]ERROR: Device path is required[reset]\n")
			return
		}

		// Run the install command in xterm
		cmdStr := fmt.Sprintf(`xterm -e bash -c 'echo will run /opt/bin/build-usb-hybrid-grub-boot.sh %s; echo "Review the command and type YES and hit enter to continue."; read c; if [ "$c" = "YES" ]; then /opt/bin/build-usb-hybrid-grub-boot.sh %s | tee /tmp/install.log; echo "Review the result and Hit enter to continue"; read ; else echo Aborted!; fi'`, device, device)

		_, exitCode, err := runCommandSilent(cmdStr)
		status := "SUCCESS"
		if err != nil || exitCode != 0 {
			status = "FAIL"
		}

		// Read install log if it exists
		logContent := ""
		if data, err := os.ReadFile("/tmp/install.log"); err == nil {
			logContent = string(data)
		}

		msg := fmt.Sprintf("Install completed with status %s.\n\nCommand output:\n%s", status, logContent)

		// Check EFI boot order
		if efibootOutput, _, _ := runCommandSilent("efibootmgr"); efibootOutput != "" {
			msg += fmt.Sprintf("\n\nCurrent EFI Boot Order:\n%s\n\nMake sure the entry 'ubuntu' is the first one to boot if you want Ubuntu to boot first.", efibootOutput)
		}

		textBuf.SetText(msg)
	})

	w.End()
	w.Show()

	return &InstallDialog{
		window:        w,
		deviceInput:   deviceInput,
		textDisplay:   textBuf,
		cancelButton:  cancelButton,
		nextButton:    nextButton,
		gpartedButton: gpartedButton,
	}
}

func main() {
	// Determine script directory
	var err error
	scriptDir = os.Getenv("LOTEUS_SCRIPT_DIR")
	if scriptDir == "" {
		exe, _ := exec.LookPath(os.Args[0])
		if exe != "" {
			scriptDir = filepath.Dir(exe)
		} else {
			scriptDir, err = os.Getwd()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error getting working directory: %v\n", err)
				os.Exit(1)
			}
		}
	}

	// Create main window - just a column of buttons on the left side (like Python GTK version)
	mainWin := fltk.NewWindow(300, 600, "Loteus System Manager")
	mainWin.SetLabel("Loteus System Manager")

	// Manually create each button to avoid Go closure loop variable bug
	y := 10
	btnSpacing := 55

	// Install Loteus
	btnInstall := fltk.NewButton(20, y, 260, 45, "Install Loteus")
	y += btnSpacing
	btnInstall.SetCallback(func() { NewInstallDialog() })

	// Update System
	btnUpdate := fltk.NewButton(20, y, 260, 45, "Update System")
	y += btnSpacing
	btnUpdate.SetCallback(func() {
		runCommandSilent(fmt.Sprintf(`xterm -e bash -c "%s/loteus-manage.py do_update; echo 'Hit enter to close'; read _junk"`, scriptDir))
	})

	// Save Config
	btnSaveConfig := fltk.NewButton(20, y, 260, 45, "Save Config")
	y += btnSpacing
	btnSaveConfig.SetCallback(func() {
		runCommandSilent(fmt.Sprintf(`xterm -e bash -c "%s/loteus-manage.py save_config; echo 'Hit enter to close'; read _junk"`, scriptDir))
	})

	// System Upgrade
	btnSysUpgrade := fltk.NewButton(20, y, 260, 45, "System Upgrade")
	y += btnSpacing
	btnSysUpgrade.SetCallback(func() {
		runCommandSilent(`xterm -e bash -c "echo 'The feature is currently not implemented yet. Hit enter to continue'; read junk"`)
	})

	// Help
	btnHelp := fltk.NewButton(20, y, 260, 45, "Help")
	y += btnSpacing
	btnHelp.SetCallback(func() {
		runCommandSilent(`xterm -e bash -c "echo 'The feature is currently not implemented yet. Hit enter to continue'; read junk"`)
	})

	// Resize USB Root
	btnResize := fltk.NewButton(20, y, 260, 45, "Resize USB Root")
	y += btnSpacing
	btnResize.SetCallback(func() {
		runCommandSilent(fmt.Sprintf(`xterm -e bash -c "%s/loteus-manage.py resize_usb_root; echo 'Hit enter to close'; read _junk"`, scriptDir))
	})

	// Create Change Image
	btnCreateImage := fltk.NewButton(20, y, 260, 45, "Create Change Image")
	y += btnSpacing
	btnCreateImage.SetCallback(func() {
		cmdStr := fmt.Sprintf("xterm -e bash -c \"echo 'Enter the size of the container. Hit enter to choose default 1G. To create 5G container enter 5000. You should make it as large as your disk space allows it.'; read IMAGE_SIZE; [ -z \\\"$IMAGE_SIZE\\\" ] && IMAGE_SIZE=1024; export IMAGE_SIZE; %s/loteus-manage.py create_change_image; echo 'Hit enter to close'; read _junk\"", scriptDir)
		runCommandSilent(cmdStr)
	})

	// Update Tools
	btnUpdateTools := fltk.NewButton(20, y, 260, 45, "Update Tools")
	y += btnSpacing
	btnUpdateTools.SetCallback(func() {
		runCommandSilent(fmt.Sprintf(`xterm -e bash -c "%s/loteus-manage.py update_tools; echo 'Hit enter to close'; read _junk"`, scriptDir))
	})

	mainWin.End()
	mainWin.Show()

	if err := fltk.Run(); err != 0 {
		fmt.Fprintf(os.Stderr, "FLTK error: %v\n", err)
		os.Exit(1)
	}
}
