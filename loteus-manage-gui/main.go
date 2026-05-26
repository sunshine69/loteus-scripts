package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	fltk "github.com/pwiecz/go-fltk"
)

// ScriptDir holds the directory where the scripts are located
var ScriptDir string

// runCmd executes a shell command and returns output, exit code, and error message
func runCmd(cmdStr string) (string, int, string) {
	cmd := exec.Command("bash", "-c", cmdStr)
	output, err := cmd.CombinedOutput()
	if err != nil {
		exitCode := 1
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		}
		return string(output), exitCode, fmt.Sprintf("Command failed with exit code %d", exitCode)
	}
	return string(output), 0, ""
}

// getDiskInfo retrieves and formats disk information
func getDiskInfo() string {
	output, _, _ := runCmd("lsblk --list --noheadings | grep -v memory | grep -v squashfs | grep -v 'loop' | grep -v 'zram' | grep -v 'crypto_LUKS' | grep -v 'EFI System' | grep -v 'BIOS boot partition'")

	_, mountPoint, size := getBaseimageLocation()

	info := fmt.Sprintf(`%s

Click the button 'Exec Gparted' to run the partition tool to create/resize
new partition to use. After exiting the disk info will be refreshed.

Then type the device name below. It can be a full disk, or just a single
partition.

CAREFULL
  - For any case the data in the full disk or the partition will be erased.
  - You can not select the disk or partition that the current live
    system runs on. They are mounted at %s with size %s`, output, mountPoint, size)

	return info
}

// getBaseimageLocation returns the mount point and size of the base image
func getBaseimageLocation() (string, string, string) {
	output, _, _ := runCmd("findmnt -n -o TARGET,SOURCE /")
	parts := strings.Fields(output)
	if len(parts) >= 2 {
		return parts[1], parts[0], "unknown"
	}
	return "", "/", "unknown"
}

// InstallDialog represents the install loteus dialog window
type InstallDialog struct {
	window         *fltk.Window
	deviceInput    *fltk.Input
	diskInfoBrowser *fltk.Browser
}

// NewInstallDialog creates a new install dialog
func NewInstallDialog() *InstallDialog {
	w, h := 800, 600
	win := fltk.NewWindow(w, h, "Install Loteus")
	win.SetCallback(func(w fltk.Widget) {
		if w == win {
			win.Hide()
		}
	})

	dlg := &InstallDialog{window: win}

	// Create a flex layout (vertical)
	flex := fltk.NewFlex(0, 0, w, h-50)
	flex.SetType(fltk.ROW)

	// Disk info browser (top section)
	diskInfoBrowser := fltk.NewBrowser(10, 10, w-20, 300)
	diskInfoBrowser.Add(getDiskInfo())
	dlg.diskInfoBrowser = diskInfoBrowser

	flex.Fixed(diskInfoBrowser, 320)

	// Bottom section for input and buttons
	bottomFlex := fltk.NewFlex(10, 340, w-20, h-390)
	bottomFlex.SetType(fltk.COLUMN)

	// Device input label and field
	label := fltk.NewLabel(10, 0, w-20, 25, "Target Device:")
	label.SetAlign(fltk.ALIGN_TOP_LEFT)
	bottomFlex.Fixed(label, 30)

	deviceInput := fltk.NewInput(10, 35, w-80, 25)
	deviceInput.SetValue("")
	dlg.deviceInput = deviceInput
	bottomFlex.Fixed(deviceInput, 30)

	// Buttons row
	buttonFlex := fltk.NewFlex(10, 75, w-20, 40)
	buttonFlex.SetType(fltk.ROW)

	gpartedBtn := fltk.NewButton(0, 0, 150, 30, "Exec GParted")
	gpartedBtn.SetCallback(func(w fltk.Widget) {
		runCmd("gparted &")
		dlg.diskInfoBrowser.Clear()
		dlg.diskInfoBrowser.Add(getDiskInfo())
	})
	buttonFlex.Fixed(gpartedBtn, 0)

	nextBtn := fltk.NewButton(160, 0, 150, 30, "Next")
	nextBtn.SetCallback(func(w fltk.Widget) {
		device := deviceInput.Value()
		if device == "" {
			dlg.diskInfoBrowser.Clear()
			dlg.diskInfoBrowser.Add("[red]ERROR: Device path is required[reset]\n")
			return
		}

		// Run the install command in xterm
		cmdStr := fmt.Sprintf(`xterm -e bash -c 'echo "Will run /opt/bin/build-usb-hybrid-grub-boot.sh %s"; echo "Review the command and type YES and hit enter to continue. "; read c; if [ "$c" = "YES" ]; then /opt/bin/build-usb-hybrid-grub-boot.sh %s | tee /tmp/install.log; echo "Review the result and Hit enter to continue"; read ; else echo Aborted!; fi'`, device, device)
		runCmd(cmdStr)

		// Read install log
		logContent := ""
		if data, err := os.ReadFile("/tmp/install.log"); err == nil {
			logContent = string(data)
		}

		status := "FAIL"
		if _, exitCode, _ := runCmd("test -f /tmp/install.log && echo ok"); exitCode == 0 {
			status = "SUCCESS"
		}

		// Check EFI boot order
		efiOutput, efiExitCode, _ := runCmd("efibootmgr")
		var msg string
		if efiExitCode == 0 {
			msg = fmt.Sprintf(`List the current EFI boot order:

%s

Make sure the entry 'ubuntu' is the first one to boot if you want Ubuntu to boot first. If not then you can set the boot order the way you want by running the command

sudo efibootmgr --bootorder XXXX,YYYY,ZZZZ

Explain:
    Explicitly set BootOrder (hex).  Any value from 0 to FFFF is accepted so long as it corresponds to an existing Boot#### variable, and zero padding is not required.

Install completed with status %s. The command output is below

%s`, efiOutput, status, logContent)
		} else {
			msg = fmt.Sprintf(`Install completed with status %s. The command output is below

%s`, status, logContent)
		}

		dlg.diskInfoBrowser.Clear()
		dlg.diskInfoBrowser.Add(msg)
	})
	buttonFlex.Fixed(nextBtn, 0)

	cancelBtn := fltk.NewButton(320, 0, 150, 30, "Cancel")
	cancelBtn.SetCallback(func(w fltk.Widget) {
		win.Hide()
	})
	buttonFlex.Fixed(cancelBtn, 0)

	bottomFlex.Fixed(buttonFlex, 40)

	flex.End()
	win.End()
	win.Show()

	return dlg
}

// MainWindow represents the main application window
type MainWindow struct {
	window *fltk.Window
	outputBrowser *fltk.Browser
}

// NewMainWindow creates the main application window
func NewMainWindow() *MainWindow {
	w, h := 900, 700
	win := fltk.NewWindow(w, h, "Loteus System Manager")
	win.SetCallback(func(w fltk.Widget) {
		if w == win {
			fltk.Quit()
		}
	})

	mw := &MainWindow{window: win}

	// Create main flex layout (vertical)
	mainFlex := fltk.NewFlex(0, 0, w, h-40)
	mainFlex.SetType(fltk.COLUMN)

	// Title label
	titleLabel := fltk.NewLabel(10, 10, w-20, 30, "Loteus System Manager - Console Edition")
	titleLabel.SetFontSize(16)
	titleLabel.SetAlign(fltk.ALIGN_CENTER)
	mainFlex.Fixed(titleLabel, 40)

	// Button panel
	buttonFlex := fltk.NewFlex(10, 55, w-20, 30)
	buttonFlex.SetType(fltk.ROW)

	buttons := []struct {
		label string
		callback func()
	}{
		{"Install Loteus", mw.onInstall},
		{"Update System", mw.onUpdate},
		{"Save Config", mw.onSaveConfig},
		{"Resize USB Root", mw.onResizeUSB},
		{"Create Change Image", mw.onCreateChangeImage},
		{"Update Tools", mw.onUpdateTools},
	}

	for _, btn := range buttons {
		button := fltk.NewButton(0, 0, 140, 30, btn.label)
		button.SetCallback(func(w fltk.Widget) {
			btn.callback()
		})
		buttonFlex.Fixed(button, 0)
	}

	mainFlex.Fixed(buttonFlex, 50)

	// Output browser (takes remaining space)
	outputBrowser := fltk.NewBrowser(10, 110, w-20, h-160)
	outputBrowser.Add("Welcome to Loteus System Manager.\nSelect an option from the buttons above.")
	mw.outputBrowser = outputBrowser
	mainFlex.Fixed(outputBrowser, 0)

	// Status bar
	statusLabel := fltk.NewLabel(10, h-35, w-20, 25, "Press ESC or click X to quit")
	statusLabel.SetFontSize(10)
	statusLabel.SetAlign(fltk.ALIGN_CENTER)
	mainFlex.Fixed(statusLabel, 30)

	mainFlex.End()
	win.End()
	win.Show()

	return mw
}

// onInstall opens the install dialog
func (mw *MainWindow) onInstall() {
	NewInstallDialog()
}

// onUpdate runs system update
func (mw *MainWindow) onUpdate() {
	mw.outputBrowser.Clear()
	mw.outputBrowser.Add("Running system update...\n")

	scriptPath := filepath.Join(ScriptDir, "loteus-manage.py")
	cmdStr := fmt.Sprintf(`xterm -e bash -c '%s do_update; echo '\''Hit enter to close'\''; read _junk'`, scriptPath)
	runCmd(cmdStr)

	mw.outputBrowser.Add("Update command completed.\n")
}

// onSaveConfig saves configuration
func (mw *MainWindow) onSaveConfig() {
	mw.outputBrowser.Clear()
	mw.outputBrowser.Add("Saving configuration...\n")

	scriptPath := filepath.Join(ScriptDir, "loteus-manage.py")
	cmdStr := fmt.Sprintf(`xterm -e bash -c '%s save_config; echo '\''Hit enter to close'\''; read _junk'`, scriptPath)
	runCmd(cmdStr)

	mw.outputBrowser.Add("Configuration saved.\n")
}

// onResizeUSB resizes USB root partition
func (mw *MainWindow) onResizeUSB() {
	mw.outputBrowser.Clear()
	mw.outputBrowser.Add("[red]WARNING: This will resize the last partition of your live USB![reset]\n\nDO NOT run this if you've installed to internal disk.\n")

	scriptPath := filepath.Join(ScriptDir, "loteus-manage.py")
	cmdStr := fmt.Sprintf(`xterm -e bash -c 'echo '\''This will resize the last partition. Type YES to continue:'\''; read c; if [ "$c" = "YES" ]; then %s resize_usb_root; echo '\''Hit enter to close'\''; read _junk; else echo Aborted; fi'`, scriptPath)
	runCmd(cmdStr)

	mw.outputBrowser.Add("Resize command completed.\n")
}

// onCreateChangeImage creates a change image with user input
func (mw *MainWindow) onCreateChangeImage() {
	// Create a simple dialog for size and name input
	dialog := fltk.NewWindow(400, 250, "Create Change Image")

	sizeLabel := fltk.NewLabel(20, 30, 150, 25, "Size in MB (default 1024):")
	sizeInput := fltk.NewIntInput(180, 30, 150, 25)
	sizeInput.SetValue(1024)

	nameLabel := fltk.NewLabel(20, 70, 150, 25, "Image Name (default: c.img):")
	nameInput := fltk.NewInput(180, 70, 150, 25)
	nameInput.SetValue("c.img")

	createBtn := fltk.NewButton(60, 130, 120, 30, "Create Image")
	createBtn.SetCallback(func(w fltk.Widget) {
		size := sizeInput.Value()
		if size == "" {
			size = "1024"
		}

		imageName := nameInput.Value()
		if imageName == "" {
			imageName = "c.img"
		}

		dialog.Hide()

		scriptPath := filepath.Join(ScriptDir, "loteus-manage.py")
		cmdStr := fmt.Sprintf(`export IMAGE_SIZE=%s && export IMAGE_NAME=%s && %s create_change_image`, size, imageName, scriptPath)

		mw.outputBrowser.Clear()
		mw.outputBrowser.Add(fmt.Sprintf("Creating %sMB change image (%s)...\n", size, imageName))
		runCmd(cmdStr)
		mw.outputBrowser.Add("Change image creation completed.\n")
	})

	cancelBtn := fltk.NewButton(220, 130, 120, 30, "Cancel")
	cancelBtn.SetCallback(func(w fltk.Widget) {
		dialog.Hide()
	})

	dialog.Add(sizeLabel)
	dialog.Add(sizeInput)
	dialog.Add(nameLabel)
	dialog.Add(nameInput)
	dialog.Add(createBtn)
	dialog.Add(cancelBtn)
	dialog.End()
	dialog.Show()
}

// onUpdateTools updates tools from GitHub
func (mw *MainWindow) onUpdateTools() {
	mw.outputBrowser.Clear()
	mw.outputBrowser.Add("Updating tools from GitHub...\n")

	scriptPath := filepath.Join(ScriptDir, "loteus-manage.py")
	cmdStr := fmt.Sprintf(`xterm -e bash -c '%s update_tools; echo '\''Hit enter to close'\''; read _junk'`, scriptPath)
	runCmd(cmdStr)

	mw.outputBrowser.Add("Tools updated.\n")
}

func main() {
	// Determine script directory
	var err error
	ScriptDir, err = os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting current directory: %v\n", err)
		os.Exit(1)
	}

	// Check for environment variable override
	if env := os.Getenv("LOTEUS_SCRIPT_DIR"); env != "" {
		ScriptDir = env
	} else if exe, err := os.Executable(); err == nil {
		ScriptDir = filepath.Dir(exe)
	}

	fmt.Printf("Starting Loteus System Manager (scripts in: %s)\n", ScriptDir)

	mw := NewMainWindow()

	fltk.Run()
	fmt.Println("Goodbye!")
}
