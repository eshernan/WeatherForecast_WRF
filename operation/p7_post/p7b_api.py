#!/bin/python3
cirrocumulus='julian@172.20.101.160'

def nco_wrfout_min(ncfile,outpath,dest):
    import os
    #outpath=directorio en master: /disco1/api/<fecha>
    #dest=directorio en cirrocumulus: /data/run/<fecha>
#    wrfout=ncfile[-30:-6]+'_min'
    wrfout=ncfile[-30:]
    apivars='P,PB,PH,PHB,T,T00,QRAIN,QCLOUD,QICE,QGRAUP,QVAPOR,U,V,W,PSFC,TSK,XLAT,XLONG,RAINC,RAINNC,Q2,T2,TH2,U10,V10,ZNU,HGT,CLDFRA,Times,XTIME'
    apivars=apivars+',AFWA_MSLP,AFWA_VIS,AFWA_VIS_DUST,AFWA_CLOUD,AFWA_CLOUD_CEIL,AFWA_CAPE,AFWA_CIN,AFWA_ZLFC,AFWA_PLFC,AFWA_LIDX,AFWA_HAIL,AFWA_LLWS'
    apivars=apivars+',AFWA_FZRA,AFWA_ICE,AFWA_TURB,AFWA_LLTURBLGT,AFWA_LLTURBMDT,AFWA_LLTURBSVR,ICINGBOT,ICINGTOP'
    print('/usr/bin/ncrcat -O -v '+apivars+' '+ncfile+' '+outpath+'/'+wrfout)
    os.system('/usr/bin/ncrcat -O -v '+apivars+' '+ncfile+' '+outpath+'/'+wrfout)
    #copiar ultima corrida
    print('scp -r '+outpath+'/'+wrfout+' '+cirrocumulus+':'+dest )
    os.system('scp -r '+outpath+'/'+wrfout+' '+cirrocumulus+':'+dest+'/fcst' )


def nc2api(settings):
    import multiprocessing as mp
    import glob,os

    path=settings['globals']['run_dir']+'fcst/wrfout*'
    outpath=settings['globals']['run_dir'].replace(settings['globals']['base_dir'],settings['globals']['backup_destination'])
    outpath=outpath.replace('run','api')
    os.system('rm -r '+"/".join(outpath.split('/')[:-2])+'/*')
    os.mkdir(outpath)
#    dest='/data/api'
    dest=outpath.replace(settings['globals']['backup_destination'],'/data')
    #borrar corridas viejas en cirrocumulus
    os.system('ssh '+cirrocumulus+' "cd /data/;./oldruns.sh"')
#    dest=outpath.replace(settings['globals']['backup_destination'],'/data')
    dest=settings['globals']['run_dir'].replace(settings['globals']['base_dir'],'/data')
    os.system('ssh '+cirrocumulus+' "mkdir '+dest+';mkdir '+dest+'/fcst"')
    nn = mp.cpu_count()
    with mp.Pool(processes=nn) as pr:
#         df_temp =  pr.starmap(wrfout_min,[(ncfile,) for ncfile in glob.glob(path)])
         df_temp =  pr.starmap(nco_wrfout_min,[(ncfile,outpath,dest) for ncfile in glob.glob(path)])
#    os.system('scp -r '+outpath+' '+cirrocumulus+':'+dest )
    diag=settings['globals']['run_dir']+'fcst/diagnostics_d0*'
    os.system('scp -r '+diag+' '+cirrocumulus+':'+dest+'/fcst' )

if __name__=='__main__':
    main()
