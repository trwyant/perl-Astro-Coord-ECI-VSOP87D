C     This Fortran 95 program is derived from example.f, which is
C     included with the VSOP87 data. It generates one of the files
C     in t/data/ from the VSOP87 model data and a list of times.
C     Output is to standard out, and for the purposes of t/model.t
C     must make use of one of the VSOP87D models, and be named
C     'vsop87d.xxxxx', where the 'xxxxx' is the name of the body
C     modelled, in all lower-case.
C
C     The interface is a bit of a hodge-podge.
C     * The path to the model file is specified on the command line.
C     * Standard input specifies what times to generate test data for.
C       This is lines in groups of three, with each group specifying the
C       start time in ISO-8601 format with leading sign for year, the
C       end time in the same firmat, and the interval between test data
C       points as dhhmmss (days, hours, minutes and seconds).  The
C       hours, minutes, and seconds must be two digits. The days can be
C       any number of digits up to the allowed size of an integer.
C     * The test data are written to standard output.

C     Other than the main line, which is entirely my own, the only
C     modification is that the IVERS and IBODY arguments to subroutine
C     VSOP87() are ignored.

C     All files are available from
C     http://cdsarc.u-strasbg.fr/viz-bin/qcat?VI/81/

      implicit none

      logical           exists

      integer           edate
      integer           etime
      double precision  ejd

      character*255     infile
      integer           inlen
      integer           inlun

      integer           curdate
      double precision  curjd
      integer           curtime

      integer           ierr
      integer           inint
      integer           insec
      integer           inmin
      integer           inhour
      integer           inday
      double precision  interval

      double precision  r( 6 )

      integer           sdate
      integer           stime
      double precision  sjd

      integer, parameter :: stderr = 0

      inlun = 0

C     Input file
      if ( iargc() .le. 0 ) goto 9000
      call getarg( 1, infile )
C     This is junk, but I can't get size= to work, and they dropped
C     Q format in Fortran 90
      inlen = index( infile, ' ' ) - 1;
      write( stderr, * ) 'Input file: "', infile(:inlen), '"'

      inquire( file=infile, exist=exists )
      if ( .not. exists ) goto 9010
      open( 1, file=infile, status='old', err=9020 )
      inlun = 1

C     Start date and time, ISO-8601 strict

1200  continue
      read( *, 1210, end=9900 ) sdate, stime
1210  format( i9, 1x, i6 )
      write( stderr, * ) 'Start date: ', sdate, '; start time: ', stime
      call datejd( sdate, stime, sjd )
      write( stderr, * ) 'Start JD: ', sjd

C     End date and time, ISO-8601 strict

      read( *, 1210, end=9900 ) edate, etime
      write( stderr, * ) 'End date: ', edate, '; end time: ', etime
      call datejd( edate, etime, ejd )
      write( stderr, * ) 'End JD: ', ejd

C     Interval, dddhhmmss

      read( *, *, end=9900 ) inint
      insec = mod( inint, 100 )
      inint = inint / 100
      inmin = mod( inint, 100 )
      inint = inint / 100
      inhour = mod( inint, 100 )
      inday = inint / 100
      interval = inday + inhour / 24.D0 + inmin / 1440.D0 + insec / 86400.d0
      write( stderr, * ) 'Interval: ', interval

      curjd = sjd
5000  continue  ! This is junk, but I can't remember how a while works

      call jddate( curjd, curdate, curtime )
      call vsop87( curjd, 0, 0, 0.d0, inlun, r, ierr )
      if ( ierr .ne. 0 ) goto 9100
      print 5100, curdate, curtime, r
5100  format( i9.8, 'T', i6.6, 10( f14.10 ) )

      curjd = curjd + interval
      if ( curjd .lt. ejd ) goto 5000
      goto 1200

9000  continue
      print *, 'Model file not specified'
      goto 9900

9010  continue
      print *, 'Failed to find file "', infile(:inlen), '"'
      goto 9900

9020  continue
      print *, 'Failed to open file "', infile(:inlen), '"'
      goto 9900

9100  continue
      print *, 'VSOP87 error ', ierr
      goto 9900

9900  continue
      if ( inlun .gt. 0 ) close( inlun )
      call exit()
      end
*
*
*
      subroutine JDDATE (tjd,idate,ihour)
*-----------------------------------------------------------------------
*
*     Object :
*     Conversion   Julian date ---> Calendar date    (Meeus formular).
*
*     Input :
*     tjd         julian date (real double precision).
*
*     Ouput :
*     idate       calendar date (integer).
*                 julian calendar before 1582 october 15
*                 gregorian calendar after.
*                 code: *yyyymmdd (* sign).
*     ihour       hour (integer).
*                 code: hhmmss.
*
*-----------------------------------------------------------------------
      implicit double precision (a-h,o-z)
      integer day,month,year
      idate=0
      ihour=0
      if (tjd.lt.0.d0) return
      t=tjd+0.5d0/86400.d0+0.5d0
      z=dint(t)
      f=t-z
      if (z.lt.2299161.d0) then
         a=z
      else
         x=dint((z-1867216.25d0)/36524.25d0)
         a=z+1.d0+x-dint(x/4.d0)
      endif
      b=a+1524.d0
      c=dint((b-122.1d0)/365.25d0)
      d=dint(365.25d0*c)
      e=dint((b-d)/30.6001d0)
      day=b-d-dint(30.6001d0*e)
      month=e-1.d0
      if (e.lt.13.5d0) then
         month=e-1.d0
      else
         month=e-13.d0
      endif
      if (month.lt.3) then
         year=c-4715.d0
      else
         year=c-4716.d0
      endif
      is=+1
      if (year.lt.0) is=-1
      idate=((iabs(year)*100+month)*100+day)*is
      f=f*24.d0
      ih=f
      f=(f-ih)*60.d0
      im=f
      f=(f-im)*60.d0
      is=f
      ihour=(ih*100+im)*100+is
      return
      end
*
*
*
      subroutine DATEJD (idate,ihour,tjd)
*-----------------------------------------------------------------------
*
*     Object :
*     Conversion   Calendar date -> Julian date    (Meeus formular).
*
*     Input :
*     idate       calendar date gregorian/julian (integer).
*                 julian calendar before 1582 october 15
*                 gregorian calendar after.
*                 code: *yyyymmdd (* sign).
*     ihour       hour (integer).
*                 code: hhmmss.
*
*     Output
*     tjd         julian date (real double precision).
*
*-----------------------------------------------------------------------
      implicit double precision (a-h,o-z)
      integer day,month,year
      dimension lm(12)
      data lm/31,28,31,30,31,30,31,31,30,31,30,31/
      tjd=0.d0
      year=idate/10000
      if (year.lt.-4713.or.year.gt.5000) return
      kdate=iabs(idate)-iabs(year)*10000
      month=kdate/100
      if (month.lt.1.or.month.gt.12) return
      day=kdate-month*100
      lm(2)=28
      if (mod(year,4).eq.0) then
         lm(2)=29
         if (year.gt.1582) then
            ncent=year/100
            if (mod(year,100).eq.0.and.mod(ncent,4).ne.0) lm(2)=28
         endif
      endif
      if (day.lt.1.or.day.gt.lm(month)) return
      is=ihour
      ih=ihour/10000
      if (ih.lt.0.or.ih.gt.24) return
      is=is-ih*10000
      im=is/100
      if (im.lt.0.or.im.gt.60) return
      is=is-im*100
      if (is.lt.0.or.is.gt.60) return
      a=0.d0
      b=0.d0
      c=0.d0
      if (month.gt.2) then
         y=year
         m=month
      else
         y=year-1
         m=month+12
      endif
      if (y.lt.0.d0) then
         c=-0.75d0
      else
         if (idate.ge.15821015) then
            a=dint(y/100.d0)
            b=2.d0-a+dint(a/4.d0)
         endif
      endif
      tjd=dint(365.25d0*y+c)+dint(30.6001d0*(m+1))+day+
     .    dfloat(ih)/24.d0+dfloat(im)/1440.d0+dfloat(is)/86400.d0+
     .    1720994.5d0+b
      return
      end
*
*
*
      subroutine CLRSCR
*-----------------------------------------------------------------------
*
*     ref : bdl-gf9412
*
*     Object :
*     Clear the screen.
*
*     Remark :
*     *DOS  for DOS system.
*     *UNX  for UNIX system.
*
*-----------------------------------------------------------------------
*
*DOS  character*7 escscr
*DOS  escscr=char(27)//char(91)//'2J'//char(27)//char(91)//'H'
*DOS  write (*,'(2x,a)') escscr
*
*UNX  call system ('clear')
*
      call system ('clear')
*
      return
      end
*
*
*
      subroutine VSOP87 (tdj,ivers,ibody,prec,lu,r,ierr)
*-----------------------------------------------------------------------
*
*     Reference : Bureau des Longitudes - PBGF9502
*
*     Object :
*
*     Substitution of time in VSOP87 solution written on a file.
*     The file corresponds to a version of VSOP87 theory and to a body.
*
*     Input :
*
*     tdj      julian date (real double precision).
*              time scale : dynamical time TDB.
*
*     ivers    version index (integer).
*              0: VSOP87 (initial solution).
*                 elliptic coordinates
*                 dynamical equinox and ecliptic J2000.
*              1: VSOP87A.
*                 rectangular coordinates
*                 heliocentric positions and velocities
*                 dynamical equinox and ecliptic J2000.
*              2: VSOP87A.
*                 spherical coordinates
*                 heliocentric positions and velocities
*                 dynamical equinox and ecliptic J2000.
*              3: VSOP87C.
*                 rectangular coordinates
*                 heliocentric positions and velocities
*                 dynamical equinox and ecliptic of the date.
*              4: VSOP87D.
*                 spherical coordinates
*                 heliocentric positions and velocities
*                 dynamical equinox and ecliptic of the date.
*              5: VSOP87E.
*                 rectangular coordinates
*                 barycentric positions and velocities
*                 dynamical equinox and ecliptic J2000.
*     TRW - THIS IS IGNORED, BUT MUST BE SPECIFIED
*
*     ibody    body index (integer).
*              0: Sun
*              1: Mercury
*              2: Venus
*              3: Earth
*              4: Mars
*              5: Jupiter
*              6: Saturn
*              7: Uranus
*              8: Neptune
*              9: Earth-Moon barycenter
*     TRW - THIS IS IGNORED, BUT MUST BE SPECIFIED
*
*     prec     relative precision (real double precision).
*
*              if prec is equal to 0 then the precision is the precision
*                 p0 of the complete solution VSOP87.
*                 Mercury    p0 =  0.6 10**-8
*                 Venus      p0 =  2.5 10**-8
*                 Earth      p0 =  2.5 10**-8
*                 Mars       p0 = 10.0 10**-8
*                 Jupiter    p0 = 35.0 10**-8
*                 Saturn     p0 = 70.0 10**-8
*                 Uranus     p0 =  8.0 10**-8
*                 Neptune    p0 = 42.0 10**-8
*
*              if prec is not equal to 0, let us say in between p0 and
*              10**-2, the precision is :
*                 for the positions :
*                 - prec*a0 au for the distances.
*                 - prec rd for the other variables.
*                 for the velocities :
*                 - prec*a0 au/day for the distances.
*                 - prec rd/day for the other variables.
*                   a0 is semi-major axis of the body.
*                 Mercury    a0 =  0.3871 ua
*                 Venus      a0 =  0.7233 ua
*                 Earth      a0 =  1.0000 ua
*                 Mars       a0 =  1.5237 ua
*                 Jupiter    a0 =  5.2026 ua
*                 Saturn     a0 =  9.5547 ua
*                 Uranus     a0 = 19.2181 ua
*                 Neptune    a0 = 30.1096 ua
*
*     lu       logical unit index of the file (integer).
*              The file corresponds to a version of VSOP87 theory and
*              a body, and it must be defined and opened before the
*              first call to subroutine VSOP87.
*
*     Output :
*
*     r(6)     array of the results (real double precision).
*
*              for elliptic coordinates :
*                  1: semi-major axis (au)
*                  2: mean longitude (rd)
*                  3: k = e*cos(pi) (rd)
*                  4: h = e*sin(pi) (rd)
*                  5: q = sin(i/2)*cos(omega) (rd)
*                  6: p = sin(i/2)*sin(omega) (rd)
*                     e:     eccentricity
*                     pi:    perihelion longitude
*                     i:     inclination
*                     omega: ascending node longitude
*
*              for rectangular coordinates :
*                  1: position x (au)
*                  2: position y (au)
*                  3: position z (au)
*                  4: velocity x (au/day)
*                  5: velocity y (au/day)
*                  6: velocity z (au/day)
*
*              for spherical coordinates :
*                  1: longitude (rd)
*                  2: latitude (rd)
*                  3: radius (au)
*                  4: longitude velocity (rd/day)
*                  5: latitude velocity (rd/day)
*                  6: radius velocity (au/day)
*
*     ierr     error index (integer).
*                  0: no error.
*                  1: file error (check up ivers index).
*                  2: file error (check up ibody index).
*                  3: precision error (check up prec parameter).
*                  4: reading file error.
*
*-----------------------------------------------------------------------
*
*     --------------------------------
*     Declarations and initializations
*     --------------------------------
*
      implicit double precision (a-h,o-z)
      character*7 bo,body(0:9)
      dimension r(6),t(-1:5),a0(0:9)
      data body/'SUN','MERCURY','VENUS','EARTH','MARS','JUPITER',
     .          'SATURN','URANUS','NEPTUNE','EMB'/
      data a0/0.01d0,0.3871d0,0.7233d0,1.d0,1.5237d0,5.2026d0,
     .        9.5547d0,19.2181d0,30.1096d0,1.d0/
      data dpi/6.283185307179586d0/
      data t/0.d0,1.d0,5*0.d0/
      data t2000/2451545.d0/
      data a1000/365250.d0/
      k=0
      ideb=0
*
      rewind (lu,err=500)
      do i=1,6
         r(i)=0.d0
      enddo
*
      t(1)=(tdj-t2000)/a1000
      do i=2,5
         t(i)=t(1)*t(i-1)
      enddo
*
      ierr=3
      if (prec.lt.0.d0.or.prec.gt.1.d-2) return
      q=dmax1(3.d0,-dlog10(prec+1.d-50))
*
*     -------------------------------------
*     File reading and substitution of time
*     -------------------------------------
*
100   continue
      read (lu,1001,end=400,err=500) iv,bo,ic,it,in
*
      if (ideb.eq.0) then
         ideb=1
         ierr=1
C         if (iv.ne.ivers) return
         ierr=2
C         if (bo.ne.body(ibody)) return
         ierr=0
         if (iv.eq.0) k=2
         if (iv.eq.2.or.iv.eq.4) k=1
      endif
*
      if (in.eq.0) goto 100
*
      p=prec/10.d0/(q-2)/(dabs(t(it))+it*dabs(t(it-1))*1.d-4+1.d-50)
      if (k.eq.0.or.(k.ne.0.and.ic.eq.5-2*k)) p=p*a0(ibody)
*
      do 200 n=1,in
         nn=n
         read (lu,1002,err=500) a,b,c
         if (dabs(a).lt.p) goto 300
         u=b+c*t(1)
         cu=dcos(u)
         r(ic)=r(ic)+a*cu*t(it)
         if (iv.eq.0) goto 200
         su=dsin(u)
         r(ic+3)=r(ic+3)+t(it-1)*it*a*cu-t(it)*a*c*su
200   continue
*
      goto 100
300   continue
*
      if (nn.eq.in) goto 100
*
      do n=nn+1,in
         read (lu,1002,err=500)
      enddo
      goto 100
*
400   continue
      if (iv.ne.0) then
         do i=4,6
            r(i)=r(i)/a1000
         enddo
      endif
*
      if (k.eq.0) return
*
      r(k)=dmod(r(k),dpi)
      if (r(k).lt.0.d0) r(k)=r(k)+dpi
      return
*
500   continue
      ierr=4
      return
*
*     -------
*     Formats
*     -------
*
1001  format (17x,i1,4x,a7,12x,i1,17x,i1,i7)
1002  format (79x,f18.11,f14.11,f20.11)
*
      end
