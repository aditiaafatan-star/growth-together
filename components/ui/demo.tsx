import { CircularTestimonials, Testimonial } from "@/components/ui/circular-testimonials";

export const teamMembers: Testimonial[] = [
  {
    name: "Hafidh Jaim T.S",
    designation: "Bougainvillea Team",
    quote: "Merawat Bougainvillea agar tumbuh kokoh, menyerap polusi, dan menghasilkan bunga kertas yang mekar lebat.",
    src: "/images/team/avatar-placeholder.jpg",
  },
  {
    name: "Firzansyah Alsy R.",
    designation: "Bougainvillea Team",
    quote: "Menjaga keseimbangan nutrisi tanah dan pemangkasan berkala untuk stimulasi tunas bract yang optimal.",
    src: "/images/team/avatar-placeholder.jpg",
  },
  {
    name: "Fatan Aditiansyah",
    designation: "Portulaca Team",
    quote: "Memantau adaptasi Portulaca, mencatat perkembangan harian, dan membangun sistem monitoring Growth Together.",
    src: "/images/team/fatan.jpg",
  },
  {
    name: "Feliza Nuril A.",
    designation: "Bougainvillea Team",
    quote: "Mengamati siklus mekar bunga bougainvillea dan memastikan kebutuhan sinar matahari penuh terpenuhi.",
    src: "/images/team/feliza.jpg",
  },
  {
    name: "Fadhil Muhammad A.",
    designation: "Portulaca Team",
    quote: "Merawat dan mendokumentasikan pertumbuhan bunga krokot agar mekar cerah setiap pagi.",
    src: "/images/team/fadhil.jpg",
    objectPosition: "center 20%",
  },
  {
    name: "Ghazy Alfi M.",
    designation: "Portulaca Team",
    quote: "Menjaga drainase pot portulaca dan memastikan teknik stek batang berakar dengan sempurna.",
    src: "/images/team/ghazy.jpg",
  },
];

export const CircularTestimonialsDemo = () => (
  <section className="w-full">
    {/* Our Team Section with Growth Together Brand Colors */}
    <div className="bg-[#F7F4EA] p-8 md:p-16 rounded-2xl min-h-[300px] flex flex-wrap gap-6 items-center justify-center relative">
      <div
        className="items-center justify-center relative flex w-full"
        style={{ maxWidth: "1456px" }}
      >
        <CircularTestimonials
          testimonials={teamMembers}
          autoplay={true}
          colors={{
            name: "#0D1A13",
            designation: "#1F4B37",
            testimony: "#17281F",
            arrowBackground: "#1F4B37",
            arrowForeground: "#F7F4EA",
            arrowHoverBackground: "#A6E06A",
          }}
          fontSizes={{
            name: "28px",
            designation: "18px",
            quote: "18px",
          }}
        />
      </div>
    </div>

    {/* Dark Theme Alternative */}
    <div className="bg-[#0D1A13] p-8 md:p-16 rounded-2xl min-h-[300px] flex flex-wrap gap-6 items-center justify-center relative mt-8">
      <div
        className="items-center justify-center relative flex w-full"
        style={{ maxWidth: "1024px" }}
      >
        <CircularTestimonials
          testimonials={teamMembers}
          autoplay={true}
          colors={{
            name: "#F7F4EA",
            designation: "#A6E06A",
            testimony: "#E4E9E0",
            arrowBackground: "#1F4B37",
            arrowForeground: "#F7F4EA",
            arrowHoverBackground: "#A6E06A",
          }}
          fontSizes={{
            name: "28px",
            designation: "18px",
            quote: "18px",
          }}
        />
      </div>
    </div>
  </section>
);

export default CircularTestimonialsDemo;
