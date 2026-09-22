#!/usr/bin/env python3
"""Run the x86 GoldSrc helper in the selected game's existing Wine/Proton prefix."""
import json,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
from runtime_launcher import parser,make_plan,diagnostic_report,write_report,LaunchError,inspect_pe
from package_validation import verify_directory

def main():
 root=Path(__file__).resolve().parent
 p=parser(root/'bin/halflife_attach.exe','x86',__doc__)
 p.add_argument('--product',choices=('halflife','opposingforce','blueshift'),required=True,help='Select the intended runner/App ID; the DLL independently verifies loaded images.')
 p.add_argument('--pid',type=int,help='Windows PID printed by --list in this same runner/prefix; never a Linux PID.')
 p.add_argument('--list',action='store_true',help='List visible Windows hl.exe processes in the selected prefix.')
 args=p.parse_args()
 try:
  manifest=verify_directory(root)
  expected={'halflife':(70,'valve'),'opposingforce':(50,'gearbox'),'blueshift':(130,'bshift')}
  if manifest.get('schema_version')!=2 or manifest.get('product')!='goldsrc' or manifest.get('module')!='ScoobyGoldSrc.dll' or set(manifest.get('products',{}))!=set(expected):raise LaunchError('Expected one unified GoldSrc package with all three product profiles.')
  for title,(appid,scope) in expected.items():
   entry=manifest['products'][title]
   if entry.get('appid')!=appid or entry.get('game_directory')!=scope or entry.get('assets')!='bin/assets/'+scope:raise LaunchError('Invalid runner identity for '+title)
  if manifest['architecture']!='x86':raise LaunchError('This package requires x86 Windows GoldSrc.')
  if args.exe.resolve()!= (root/'bin/halflife_attach.exe').resolve():raise LaunchError('Use the packaged helper; --exe overrides are unsupported.')
  adapter=root/'bin'/manifest['module']
  if args.module and args.module.resolve()!=adapter.resolve():raise LaunchError('Module must match this package.')
  args.module=adapter if args.game_exe else None
  selected=manifest['products'][args.product]
  if args.runner=='proton' and args.appid!=str(selected['appid']):raise LaunchError('Proton App ID must match this exact game package.')
  if args.pid is not None and not 0<args.pid<=0xffffffff:raise LaunchError('Invalid Windows PID.')
  if args.pid and args.list:raise LaunchError('Choose --list or --pid.')
  if not args.list and not (args.diagnose or args.dry_run):
   if not args.pid or not args.game_exe:raise LaunchError('Attach requires --pid and --game-exe. Run --list in this prefix first.')
  if args.game_exe:inspect_pe(args.game_exe,expected_arch='x86')
  forwarded=[str(args.pid),'--local-module',adapter.name] if args.pid else ['--list']
  plan=make_plan(args,forwarded);report=diagnostic_report(plan)
  report.update({'product':selected['product'],'profile':selected['profile'],'module_sha256':manifest['files']['bin/'+adapter.name]['sha256'],'linux_runtime_verified':False})
  if args.report:write_report(args.report,report)
  if args.diagnose or args.dry_run:print(json.dumps(report,indent=2));return 0
  return subprocess.run(plan.command,cwd=plan.cwd,env=plan.environment,check=False).returncode
 except (ValueError,OSError,KeyError) as e:print('GoldSrc compatibility: '+str(e),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
