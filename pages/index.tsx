import type { NextPage } from 'next'
import IncidentsSection from "../src/incidents"
import ServicesSection from "../src/services"

const Home: NextPage = () => {
  return (
    <div className='h-full w-full '>
      <div className="mt-20 absolute inset-0 bg-[url(/grid.svg)] bg-center [mask-image:linear-gradient(180deg,white,rgba(255,255,255,0))]"></div>
      <div className="w-full h-40 absolute bg-light-purple dark:purple dark:bg-black">
        <div className="sm:ml-0 ml-5 mr-0 mt-3 md:pl-80 md:pr-80 sm:w-full h-full bg-purple-500 dark:bg-black">
          <a href="https://pad.osm.lat/s/FTvJUqi9u">
          <img 
            src="/OSM_LatAm_Logo.svg" 
            width={100} 
            height={100} 
            className="w-40 h-16" 
            alt="OSM LatAm"
          />
          </a>
        </div>
      </div>
      <div className='mt-20 w-full absolute overflow-scroll	'>
        <ServicesSection />
        <div className="text-center text-base font-medium leading-7 text-gray-900">
          <a href="https://pad.osm.lat/s/FTvJUqi9u">Comunidad OpenStreetMap LatAm</a><br/>
          Si ves un problema, puedes <a href="https://github.com/OSMLatam/status/issues">crear un incidente en GitHub</a>.
        </div>
      </div >
    </div>
  )
}

export default Home;
