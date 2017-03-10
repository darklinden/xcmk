#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
import re
import uuid
import sys
import json
import shutil
import subprocess
import plistlib
import errno

def run_cmd(cmd):
    print("run cmd: " + " ".join(cmd))
    print("")
    print("")
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    output = ""
    # Poll process for new output until finished
    while True:
        nextline = process.stdout.readline()
        if nextline == '' and process.poll() is not None:
            break

        sys.stdout.write(nextline)
        sys.stdout.flush()
        output = output + nextline

    xoutput, err = process.communicate()
    exitCode = process.returncode

    if (exitCode != 0):
        if err is not None:
            print(err)

    print("")
    print("")
    return output

def self_install(file, des):
    file_path = os.path.realpath(file)

    filename = file_path

    pos = filename.rfind("/")
    if pos:
        filename = filename[pos + 1:]

    pos = filename.find(".")
    if pos:
        filename = filename[:pos]

    to_path = os.path.join(des, filename)

    print("installing [" + file_path + "] \n\tto [" + to_path + "]")
    if os.path.isfile(to_path):
        os.remove(to_path)

    shutil.copy(file_path, to_path)

    os.system('/bin/chmod a+x ' + to_path)

def regex_replace(path, rgstr, rpstr):

    print("regex_replace " + path + " " + rgstr + " " + rpstr)
    
    result = regex_find(path, rgstr)

    if len(result) > 0:
        print("regex found strings:")
        print(result)
        print("replacing to [" + rpstr + "] ...")

        # open the file
        f = open(path, "r")
        content = f.read()
        f.close()
        
        # replace
        new_content = re.sub(rgstr, rpstr, content)

        # save to file
        f = open(path, "w")
        f.write(new_content)
        f.close()

    else:
        print("regex found nothing, exit")
    
def mkdir_p(path):
    # print("mkdir_p: " + path)
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def regex_find(path, rgstr):
    # open the file
    f = open(path, "r")
    content = f.read()
    f.close()

    # replace
    pattern = re.compile(rgstr)
    results = pattern.findall(content)
    return results
    
def dir_content(folder):
    fList = os.listdir(folder)
    dirs = []
    files = []
    for f in fList:
        fPath = os.path.join(folder, f)
        if os.path.isfile(fPath):
            files.append(f)
        elif os.path.isdir(fPath):
            dirs.append(f)

    return dirs, files

def read_cmd(tip_str, cmds=["q"]):

    cmd = ""
    success = False
    while not success:

        cmd = raw_input(tip_str)
        cmd = cmd.strip()
        cmd = cmd.lower()

        if cmd in cmds:
            success = True

    return cmd, success

def __main__():

    # self_install
    if len(sys.argv) > 1 and sys.argv[1] == 'install':
        self_install("xcmk.py", "/usr/local/bin")
        return

    param = ""
    autoMode = False
    args = []

    if len(sys.argv) > 1:
        idx = 1
        while idx < len(sys.argv) - 1:
            a = str(sys.argv[idx])
            if (a.startswith('-')):
                args.append(a)
            idx += 1

        param = sys.argv[len(sys.argv) - 1]

    if ("-a" in args) or ("-A" in args):
        autoMode = True

    if not str(param).startswith("/"):
        param = os.path.join(os.getcwd(), param)

    if not str(param).endswith("project.pbxproj"):
        param = os.path.join(param, "project.pbxproj")

    if os.path.isfile(param):
        XCODE_PRJ_PATH = param
    else:
        print("using xcmk [xcode-project-path] [-a: auto mode] to auto build ipa")
        return

    regex_replace(XCODE_PRJ_PATH, "CODE_SIGN_RESOURCE_RULES_PATH[ ]*=.*\n", "CODE_SIGN_RESOURCE_RULES_PATH = \"\";\n")

    if not autoMode:
        # find bundle id
        bundle_id = ""
        results = regex_find(XCODE_PRJ_PATH, "PRODUCT_BUNDLE_IDENTIFIER ?= ?\"?.+\"?;")
        if len(results) > 0:
            tmp = results[0]
            tmp = tmp[len("PRODUCT_BUNDLE_IDENTIFIER"):]
            bundle_id = tmp.strip("=; \t\n\"")

        print("get bundle id: [" + bundle_id + "]\n")

        # profiles path
        home = os.path.expanduser("~")
        profiles_path = os.path.join(home, "Library/MobileDevice/Provisioning Profiles/")

        file_duplicate_detector = {}
        profile_list_name_match = []
        profile_list = []

        dirs, files = dir_content(profiles_path)
        for fpath in files:
            if fpath.split(".")[-1].lower() != "mobileprovision":
                continue

            path = os.path.join(profiles_path, fpath)
            f = open(path, "r")
            content = f.read()
            f.close()

            # print("walking through: " + fpath)
            start = content.find("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
            end = content.find("</plist>")

            content = content[:(end + len("</plist>"))][start:]

            plist_obj = plistlib.readPlistFromString(content)

            Entitlements = plist_obj["Entitlements"]

            app_id = Entitlements["application-identifier"]
            team_id = Entitlements["com.apple.developer.team-identifier"]

            e_bundle_id = "-"
            if app_id.startswith(team_id):
                e_bundle_id = app_id[len(team_id):]
                e_bundle_id = e_bundle_id.strip(".")
                if e_bundle_id == "":
                    e_bundle_id = "*"

            if e_bundle_id != bundle_id and e_bundle_id != "*":
                continue

            # print("found bundleid [" + bundle_id + "] in [" + fpath + "]\n")

            ProvisionedDevices = plist_obj.get("ProvisionedDevices", [])
            # print("get ProvisionedDevices: [" + ProvisionedDevices + "]")

            if len(ProvisionedDevices) != 0:
                profile_mode = "contains devices"
            else:
                profile_mode = "no device list"

            UUID = plist_obj["UUID"]
            # print("get UUID: [" + UUID + "]\n")

            TeamName = plist_obj["TeamName"]
            # print("get TeamName: [" + TeamName + "]\n")

            Name = plist_obj["Name"]
            # print("get Name: [" + Name + "]\n")

            ExpirationDate = plist_obj["ExpirationDate"]

            TeamIdentifier = plist_obj["TeamIdentifier"][0]

            obj = {}
            obj["path"] = fpath
            obj["Name"] = Name
            obj["mode"] = profile_mode
            obj["UUID"] = UUID
            obj["TeamName"] = TeamName
            obj["TeamIdentifier"] = TeamIdentifier
            obj["ExpirationDate"] = ExpirationDate

            key = "[" + Name + "]-[" + TeamName + "]-[" + profile_mode + "]"
            saved_obj = file_duplicate_detector.get(key, {})
            if saved_obj == {}:
                file_duplicate_detector[key] = obj
                if bundle_id == e_bundle_id:
                    profile_list_name_match.append(obj)
                else:
                    profile_list.append(obj)
            else:
                if obj["ExpirationDate"] > saved_obj["ExpirationDate"]:
                    # print("remove " + saved_obj["path"])
                    # os.remove(os.path.join(profiles_path, saved_obj["path"]))

                    if bundle_id == e_bundle_id:
                        new_list = []
                        for one_obj in profile_list_name_match:
                            if one_obj["Name"] == obj["Name"] and one_obj["mode"] == obj["mode"] and one_obj["TeamName"] == obj["TeamName"]:
                                continue
                            else:
                                new_list.append(one_obj)

                        profile_list_name_match = new_list
                        profile_list_name_match.append(obj)
                    else:
                        new_list = []
                        for one_obj in profile_list:
                            if one_obj["Name"] == obj["Name"] and one_obj["mode"] == obj["mode"] and one_obj["TeamName"] == obj["TeamName"]:
                                continue
                            else:
                                new_list.append(one_obj)

                        profile_list = new_list
                        profile_list.append(obj)

        print("found profiles could sign this bundle id:")


        if len(profile_list_name_match) > 0:

            profile_list_name_match = sorted(profile_list_name_match, key=lambda obj: obj["TeamName"])

            cmds = ["q"]
            idx = 0
            while idx < len(profile_list_name_match):
                cmds.append(str(idx))
                # cmds.append("s" + str(idx))
                obj = profile_list_name_match[idx]
                print(str(idx) + "\t[" + obj["Name"] \
                + "]\n\t[" + obj["mode"] \
                + "]\n\t[" + obj["TeamName"] \
                + "]\n\t[" + obj["TeamIdentifier"] \
                + "]\n\t[" + obj["UUID"] \
                + "]\n\t[" + str(obj["ExpirationDate"]) \
                + "]\n\t[" + os.path.join(profiles_path, obj["UUID"] + ".mobileprovision]\n"))
                idx = idx + 1

            cmd, success = read_cmd("input number to use profile, \"q\" to exit: ", cmds) # \"sx\" to use x whitout change,
            if success:
                if cmd.strip() == "q":
                    return 0
                else:
                    if cmd.startswith("s"):
                        cmd = cmd[1:]
                        obj = profile_list_name_match[int(cmd)]
                    else:
                        obj = profile_list_name_match[int(cmd)]
                        regex_replace(XCODE_PRJ_PATH, "CODE_SIGN_IDENTITY[ ]+=[ ]+[\",a-z,A-Z,0-9,.,\\-,_,;, ]*", "CODE_SIGN_IDENTITY = \"\";")
                        regex_replace(XCODE_PRJ_PATH, "\"CODE_SIGN_IDENTITY\\[sdk=iphoneos\\*\\]\"[ ]*=[ ,\"]*[a-z,A-Z,0-9,\\-,_,;, ,\"]*", "\"CODE_SIGN_IDENTITY[sdk=iphoneos*]\" = \"\";")
                        regex_replace(XCODE_PRJ_PATH, "PROVISIONING_PROFILE[ ]+=[ ]+[\",a-z,A-Z,0-9,.,\\-,_,;]*", "PROVISIONING_PROFILE = \"" + obj["UUID"] + "\";")

        else:

            profile_list = sorted(profile_list, key=lambda obj: obj["TeamName"])

            cmds = ["q"]
            idx = 0
            while idx < len(profile_list):
                cmds.append(str(idx))
                # cmds.append("s" + str(idx))
                obj = profile_list[idx]
                print(str(idx) + "\t[" + obj["Name"] \
                + "]\n\t[" + obj["mode"] \
                + "]\n\t[" + obj["TeamName"] \
                + "]\n\t[" + obj["TeamIdentifier"] \
                + "]\n\t[" + obj["UUID"] \
                + "]\n\t[" + str(obj["ExpirationDate"]) \
                + "]\n\t[" + os.path.join(profiles_path, obj["UUID"] + ".mobileprovision]\n"))
                idx = idx + 1

            cmd, success = read_cmd("input number to use profile, \"q\" to exit: ", cmds) # \"sx\" to use x whitout change,
            if success:
                if cmd.strip() == "q":
                    return 0
                else:
                    if cmd.startswith("s"):
                        cmd = cmd[1:]
                        obj = profile_list[int(cmd)]
                    else:
                        obj = profile_list[int(cmd)]
                        regex_replace(XCODE_PRJ_PATH, "CODE_SIGN_IDENTITY[ ]+=[ ]+[\",a-z,A-Z,0-9,.,\\-,_,;, ]*", "CODE_SIGN_IDENTITY = \"\";")
                        regex_replace(XCODE_PRJ_PATH, "\"CODE_SIGN_IDENTITY\\[sdk=iphoneos\\*\\]\"[ ]*=[ ,\"]*[a-z,A-Z,0-9,\\-,_,;, ,\"]*", "\"CODE_SIGN_IDENTITY[sdk=iphoneos*]\" = \"\";")
                        regex_replace(XCODE_PRJ_PATH, "PROVISIONING_PROFILE[ ]+=[ ]+[\",a-z,A-Z,0-9,.,\\-,_,;]*", "PROVISIONING_PROFILE = \"" + obj["UUID"] + "\";")

    xcpaths = os.path.split(XCODE_PRJ_PATH)
    if len(xcpaths) > 1:
        tmp = xcpaths[0]
        xcpaths = os.path.split(tmp)
        if len(xcpaths) > 1:
            prj_path = xcpaths[0]

    build_path = os.path.join(prj_path, "build")
    if os.path.isdir(build_path):
        shutil.rmtree(build_path)
    mkdir_p(build_path)

    arc_path = os.path.join(build_path, "build.xcarchive")

    print("reading schemes ... \n");
    print (prj_path)
    os.chdir(prj_path)
    schemes = run_cmd(["/usr/bin/xcodebuild", "-list"]);
    start = False
    tmp_schemes_lines = schemes.split("\n")
    schemes_lines = []
    for l in tmp_schemes_lines:
        l = l.strip()
        if start and len(l) > 0:
            schemes_lines.append(l)

        if l == "Schemes:":
            start = True

    tmp = os.path.basename(XCODE_PRJ_PATH)
    prj_name, ext = os.path.split(tmp)

    filted_schemes = []
    for l in schemes_lines:
        if str(l).find(prj_name) != -1:
            filted_schemes.append(l)

    if len(filted_schemes) > 0:
        cmds = ["q"]
        idx = 0
        while idx < len(filted_schemes):
            cmds.append(str(idx))
            l = filted_schemes[idx]
            print(str(idx) + "\t[" + l + "]")
            idx = idx + 1

        cmd, success = read_cmd("input number to use scheme, \"q\" to exit: ", cmds)
        if success:
            if cmd.strip() == "q":
                return 0
            else:
                SchemeName = filted_schemes[int(cmd)]
                print("select scheme: [" + SchemeName + "]")
    else:
        cmds = ["q"]
        idx = 0
        while idx < len(schemes_lines):
            cmds.append(str(idx))
            l = schemes_lines[idx]
            print(str(idx) + "\t[" + l + "]")
            idx = idx + 1

        cmd, success = read_cmd("input number to use scheme, \"q\" to exit: ", cmds)
        if success:
            if cmd.strip() == "q":
                return 0
            else:
                SchemeName = schemes_lines[int(cmd)]
                print("select scheme: [" + SchemeName + "]")

    print("building archive ...")

    os.chdir(prj_path)
    
    build_result = run_cmd(["/usr/bin/xcodebuild", "-scheme", SchemeName, "clean", "archive", "-archivePath", arc_path])

    if "** ARCHIVE SUCCEEDED **" not in build_result:
        print("build failed");
        return 0

    print("build success, exporting ipa ... \n")
    
    # ipa_method = ["app-store", "ad-hoc", "package", "enterprise", "development", "developer-id"]
    # cmds = ["q"]
    # idx = 0
    # while idx < len(ipa_method):
    #     cmds.append(str(idx))
    #     print(str(idx) + "\t[" + ipa_method[idx] + "]")
    #     idx = idx + 1
    # cmd, success = read_cmd("input number to select ipa method, \"q\" to exit: ", cmds)
    # if success:
    #     if cmd.strip() == "q":
    #         return 0
    #     else:
    #         s_method = ipa_method[int(cmd)]
    # ipa_plist_path = ipa_plist() 

    ipa_path = os.path.join(build_path, "build.ipa")

    # export_result = run_cmd(["/usr/bin/xcodebuild", "-exportArchive", "-exportFormat", "ipa", "-archivePath", arc_path, "-exportPath", ipa_path, "-exportProvisioningProfile", '"' + obj["Name"] + '"'])
    export_result = run_cmd(["/usr/bin/xcodebuild", "-exportArchive", "-archivePath", arc_path, "-exportPath", ipa_path])

    if "** EXPORT SUCCEEDED **" not in export_result:
        print("export failed")
        return 0

    print ("ipa May Exported At [" + ipa_path + "]")

    print("Done")

__main__()
